# The resolver converts all incidents to intervals with a start and end
# then divides the intervals into subintervals based on the locations
# of the endpoints and locations. This is illustrated below:
#
# Cases
#   +
#   |                  I1 Country
#   |   +------------------------------------+
#   |   |      |               |     |       |
#   |   |      |      B2       |     |   D2  |I3 State
#   |   |      |               |     +--------------------+
#   |   |      | I2 State      |     |       |            |
#   |   |      +---------------+     |       |            |
#   |   |      |               |     |       |            |
#   |   |      |               |     |       |            |
#   |   |      |               |     |       |            |
#   |   |      |               |     |       |            |
#   |   |      |               |     |       |            |
#   |   |  A   |      B1       |  C  |   D1  |     E      |
#   +-------------------------------------------------------------------------+
#   +                         Time
#
# There are two resolution methods implemented. One is based on
# linear programming. The other chooses the maximum incident case rates over
# each sub-interval and uses a topological sort to ensure the larger of
# the sub-interval or sum of the sub-location sub-interval counts is used.
# The linear programming method is slower and cannot handle as many incidents.
# Linear programming has a potential advantage when handling bi-directional
# relationships between case rates. For instance, it may be desirable to
# decrease the case rates of some of the sub-intervals that overlap an incident
# interval if one of them has a rate that is greater than the incident's case
# rate.

import LocationTree from './LocationTree'
import Solver from './LPSolver'

MILLIS_PER_DAY = 1000 * 60 * 60 * 24

class Endpoint
  constructor: (@isStart, @offset, @interval) ->

intervalToEndpoints = (interval) ->
  console.assert Number(interval.startDate) < Number(interval.endDate)
  [
    new Endpoint(true, Number(interval.startDate), interval)
    new Endpoint(false, Number(interval.endDate), interval)
  ]

differentailIncidentsToSubIntervals = (incidents) ->
  if incidents.length == 0
    return []
  endpoints = []
  locationsById = {}
  incidents.forEach (incident, idx) ->
    incident.id = idx
    console.assert(incident.locations.length > 0)
    for location in incident.locations
      locationsById[location.id] = location
    endpoints = endpoints.concat(intervalToEndpoints(incident))
  endpoints = endpoints.sort (a, b)->
    if a.offset < b.offset
      -1
    else if a.offset > b.offset
      1
    # endpoints before startpoints
    else if a.isStart and not b.isStart
      1
    else if not a.isStart and b.isStart
      -1
    else
      0
  locationTree = LocationTree.from(_.values(locationsById))
  topLocations = locationTree.children.map (x)->x.value
  priorEndpoint = endpoints[0]
  console.assert priorEndpoint.isStart
  SELToIncidents = {}
  activeIntervals = [priorEndpoint.interval]
  endpoints.slice(1).forEach (endpoint) ->
    if priorEndpoint.offset != endpoint.offset
      # Ensure a subinterval is created for the top level locations between
      # every endpoint.
      for location in topLocations
        key = "#{priorEndpoint.offset},#{endpoint.offset},#{location.id}"
        SELToIncidents[key] = SELToIncidents[key] or []
      for interval in activeIntervals
        for location in interval.locations
          key = "#{priorEndpoint.offset},#{endpoint.offset},#{location.id}"
          SELToIncidents[key] = _.uniq((SELToIncidents[key] or []).concat(
            interval.id
          ))
    if endpoint.isStart
      activeIntervals.push(endpoint.interval)
    else
      activeIntervals = _.without(activeIntervals, endpoint.interval)
    priorEndpoint = endpoint
  SELs = []
  idx = 0
  for key, incidentIds of SELToIncidents
    [start, end, locationId] = key.split(',')
    SELs.push
      id: idx
      start: parseInt(start)
      end: parseInt(end)
      locationId: locationId
      location: locationsById[locationId]
      incidentIds: incidentIds
    idx++
  return SELs

subIntervalsToLP = (incidents, subIntervals)->
  IncidentToSELs = {}
  SEToLocations = {}
  SELToId = {}
  subIntervals.forEach (interval)->
    {start, end, incidentIds, location} = interval
    for incidentId in incidentIds
      IncidentToSELs[incidentId] = (IncidentToSELs[incidentId] or []).concat(interval)
    SELToId["#{start},#{end},#{location.id}"] = interval.id
    key = "#{start},#{end}"
    SEToLocations[key] = (SEToLocations[key] or []).concat(location)
  SEToLocationTree = {}
  for key, locations of SEToLocations
    SEToLocationTree[key] = LocationTree.from(locations)
  constraints = []
  incidents.forEach((incident, incidentId)->
    mainConstraintVars = []
    incidentSubs = IncidentToSELs[incidentId]
    if not incidentSubs
      console.log "Error: No subintervals for", incidentId
    incidentLength = (Number(incident.endDate) - Number(incident.startDate)) / MILLIS_PER_DAY
    incidentRate = incident.count / incidentLength
    for subInterval in incidentSubs
      { id, start, end } = subInterval
      itervalLengthDays = (end - start) / MILLIS_PER_DAY
      # The absX variables are the absolute value of the max difference
      # between the subinterval's rate and the source incidents' overall rates.
      # The objective function will attempt to minimize this quantity.
      # Note: It might be simpler in some regards to create an absX variable for
      # each incident sub-interval pair so the differences are all minimized
      # rather than only the max difference. However, it would increase the
      # number of variables and it would give more weight to repeated incidents.
      constraints.push("#{(1 / itervalLengthDays).toFixed(12)} s#{id} -1 abs#{id} <= #{incidentRate}")
      constraints.push("#{(1 / itervalLengthDays).toFixed(12)} s#{id} 1 abs#{id} >= #{incidentRate}")
      mainConstraintVars.push "1 s" + id
    # The sum of the counts over over all subintervals must be greater than
    # the count over the incident interval.
    constraints.push(mainConstraintVars.join(" ") + " >= " + incident.count)
  )
  subIntervals.forEach ({id, start, end, locationId})->
    locationTree = SEToLocationTree[start + "," + end]
    subLocConstraintVars = ["1 s" + id]
    node = locationTree.getNodeById(locationId)
    for sublocation in node.children
      sublocSELId = SELToId[start + "," + end + "," + sublocation.value.id]
      subLocConstraintVars.push "-1 s" + sublocSELId
    # The sublocations must have a count less than their parent over
    # each sub interval
    constraints.push(subLocConstraintVars.join(" ") + " >= 0")
  # This can constrain the results to all be integers but it slows things
  # down by 5x or more.
  # constraints = constraints.concat(subIntervals.map (s)->"int s#{s.id}")
  return [
    "min: " + subIntervals.map((i, idx)-> "1 abs#{idx}").join(" ")
  ].concat(constraints)

# This method uses linear programming to compute the number of cases in
# each sub-interval.
# There is a variable for each subinterval that indicates how many cases occur
# within it.
# The constraints are formed by the incident intervals. The number of cases in
# the subintervals an interval contains must sum to at least the number of cases
# in the interval.
# The objective function minimizes the combined absolute values of the
# max difference between the subinterval case rates and their associated incident
# case rates. Essentially, it tries to make the resolved rates fit the
# rates in the incident reports as closely as possible.
extendSubIntervalsWithValuesLP = (incidents, subIntervals)->
  model = subIntervalsToLP(incidents, subIntervals)
  solution = Solver.Solve(Solver.ReformatLP(model))
  # set default values for subintervals
  subIntervals.forEach (s)->
    s.value = 0
  for key, value of solution
    if key.startsWith("s")
      subId = key.split("s")[1]
      subInterval = subIntervals[parseInt(subId)]
      subInterval.value = value

topologicalSort = (incomingNodesInit) ->
  # Copy incoming nodes
  incomingNodes = incomingNodesInit.map (nodes) -> new Set(nodes)
  # Create outgoing node index
  outgoingNodes = incomingNodes.map(-> new Set())
  incomingNodes.forEach (incomingIds, id) ->
    incomingIds.forEach (incomingId) ->
      outgoingNodes[incomingId].add(id)
  # Based on Kahn's algorithm
  sortedIds = []
  noIncomingNodes = []
  incomingNodes.forEach (incomingNodes, id) ->
    if incomingNodes.size == 0
      noIncomingNodes.push(id)
  while noIncomingNodes.length > 0
    nodeId = noIncomingNodes.pop()
    sortedIds.push(nodeId)
    outgoingNodes[nodeId].forEach (outgoingNodeId) ->
      outgoingNodeIncomingNodes = incomingNodes[outgoingNodeId]
      outgoingNodeIncomingNodes.delete(nodeId)
      if outgoingNodeIncomingNodes.size == 0
        noIncomingNodes.push(outgoingNodeId)
    outgoingNodes[nodeId] = new Set()
  # Check for cycles
  console.assert(incomingNodes.every((nodes) -> nodes.size == 0))
  console.assert(outgoingNodes.every((nodes) -> nodes.size == 0))
  return sortedIds

# This resolves incidents using a method where the max incident over each
# subinterval is selected as the subinterval's rate. The rate for each location
# is the greater of the location's rate or the sum of its child location rates.
# Toplological sorting is used to resolve the child location rates.
extendSubIntervalsWithValuesTS = (incidents, subIntervals) ->
  IncidentToSELs = {}
  SEToLocations = {}
  SELToId = {}
  subIntervals.forEach (interval) ->
    {start, end, incidentIds, location} = interval
    for incidentId in incidentIds
      IncidentToSELs[incidentId] = (IncidentToSELs[incidentId] or []).concat(interval)
    SELToId["#{start},#{end},#{location.id}"] = interval.id
    key = "#{start},#{end}"
    SEToLocations[key] = (SEToLocations[key] or []).concat(location)
  SEToLocationTree = {}
  for key, locations of SEToLocations
    SEToLocationTree[key] = LocationTree.from(locations)
  subIntervalRates = subIntervals.map(-> [])
  incidents.forEach((incident, incidentId) ->
    incidentSubs = IncidentToSELs[incidentId]
    if not incidentSubs
      console.log "Error: No subintervals for", incidentId
    incidentLength = (Number(incident.endDate) - Number(incident.startDate)) / MILLIS_PER_DAY
    # The case rate is divided by the number of locations in the incident
    # so that a report of cases distributed in 3 states won't result in
    # a count of triple that for the country.
    incidentRate = incident.count / incidentLength / incident.locations.length
    for subInterval in incidentSubs
      subIntervalRates[subInterval.id].push(incidentRate)
  )
  subIntervalRates = subIntervalRates.map (rates) ->
    _.max(rates.concat(0))
  # incomingNodes specifies a DAG where there is a node for each sub-interval
  # and directed edges that indicate the sub-interval of the starting node
  # contributes to the case rate of of the sub-interval of the ending node.
  incomingNodes = []
  subIntervals.forEach ({id}) ->
    incomingNodes[id] = new Set()
  subIntervals.forEach ({id, start, end, locationId}) ->
    locationTree = SEToLocationTree[start + "," + end]
    ltNode = locationTree.getNodeById(locationId)
    for sublocation in ltNode.children
      sublocSubIntId = SELToId[start + "," + end + "," + sublocation.value.id]
      incomingNodes[id].add(sublocSubIntId)
  sortedSubIntervalIds = topologicalSort(incomingNodes)
  for id in sortedSubIntervalIds
    subLocationTotal = 0
    incomingNodes[id].forEach (incomingNodeId) ->
      subLocationTotal += subIntervalRates[incomingNodeId]
    subIntervalRates[id] = Math.max(subIntervalRates[id], subLocationTotal)
  subIntervals.forEach (subInterval) ->
    {start, end} = subInterval
    itervalLengthDays = (end - start) / MILLIS_PER_DAY
    subInterval.value = subIntervalRates[subInterval.id] * itervalLengthDays

extendSubIntervalsWithValues = (incidents, subIntervals, method="topologicalSort") ->
  if method is "topologicalSort"
    extendSubIntervalsWithValuesTS(incidents, subIntervals)
  else
    extendSubIntervalsWithValuesLP(incidents, subIntervals)

export intervalToEndpoints = intervalToEndpoints
export differentailIncidentsToSubIntervals = differentailIncidentsToSubIntervals
export subIntervalsToLP = subIntervalsToLP
export extendSubIntervalsWithValues = extendSubIntervalsWithValues
