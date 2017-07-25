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
# In order to compute the number of cases that fall within each subinterval
# linear programming is used.
# There is a variable for each subinterval that indicates how many cases occur
# within it.
# The constraints are formed by the incident intervals. The number of cases in the 
# subintervals an interval contains must sum to at least the number of cases in
# the interval.
# The objective function minimizes the following objectives
# by weighting the objectives that should take priority higher:
#
# 1. The sum of the maximum case rates in each interval.
# 2. The sum of the sum of all the subinterval counts in each interval.
# 3. The negative minimum case rate.
#
# I arrived at this function by attempting to make the solution fit the
# incident reports as closely as possible. At first I only used the second
# objective. However, it often lead to solutions where cases were not
# distributed evenly across subintervals.
# To see an example of the uneven distribution problem, imagine minimizing the
# subinterval counts of I1 and I3 from the plot above. Without an incentive
# to evenly distribte their counts, an optimal soultion could allocate
# zero cases to the D subintervals by overinflating the others or vice versa.
# To remidy this, I introduced the first and third objectives.
# They are designed to press the minimum and maximum rates of the intervals
# together and prevent all the cases in an incident from being unevely allocated
# to the maximum rate subintervals when they could be allocated to others.
# The first objective was initially a secondary objective.
# However, when inconsistent counts were used - for instance, 
# an interval with 100 cases inside an interval with only 10 cases -
# objective 2 would override the other objectives and cause problems
# where counts were distributed unevenly.
import LocationTree from './LocationTree.coffee'
import solverExport from 'javascript-lp-solver'

class Endpoint
  constructor: (@isStart, @offset, @interval) ->

intervalToEndpoints = (interval)->
  console.assert Number(interval.startDate) < Number(interval.endDate)
  [
    new Endpoint(true, Number(interval.startDate), interval)
    new Endpoint(false, Number(interval.endDate), interval)
  ]

differentailIncidentsToSubIntervals = (incidents)->
  if incidents.length == 0
    return []
  endpoints = []
  locationsById = {}
  incidents.forEach (incident, idx)->
    incident.id = idx
    # Remove contained locations from loc array
    incident.locations = LocationTree.from(incident.locations).children.map (x)->x.value
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
  endpoints.slice(1).forEach (endpoint)->
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
  objective = subIntervals.map -> 0
  incidents.forEach((incident, incidentId)->
    mainConstraintVars = []
    incidentSubs = IncidentToSELs[incidentId]
    if not incidentSubs
      console.log "Error: No subintervals for", incidentId
    for subInterval in incidentSubs
      { id, start, end } = subInterval
      itervalLengthDays = (end - start) / (1000 * 60 * 60 * 24)
      # The min/max incidentId variables are the minimum or maximum
      # rates in the incident interval. The objective function will
      # minimize/maximize these respectively.
      constraints.push("#{(1 / itervalLengthDays).toFixed(12)} s#{id} -1 min#{incidentId} >= 0")
      constraints.push("#{(1 / itervalLengthDays).toFixed(12)} s#{id} -1 max#{incidentId} <= 0")
      objective[id] += 1
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
    "min: " + objective.map((x, idx)-> "#{x} s#{idx}").join(" ") + " " +
      incidents.map((i, idx)-> "10000 max#{idx} -0.001 min#{idx}").join(" ")
  ].concat(constraints)

extendSubIntervalsWithValues = (incidents, subIntervals)->
  model = subIntervalsToLP(incidents, subIntervals)
  solution = solver.Solve(solver.ReformatLP(model))
  # set default values for subintervals
  subIntervals.forEach (s)->
    s.value = 0
  for key, value of solution
    if key.startsWith("s")
      subId = key.split("s")[1]
      subInterval = subIntervals[parseInt(subId)]
      subInterval.value = value

export intervalToEndpoints = intervalToEndpoints
export differentailIncidentsToSubIntervals = differentailIncidentsToSubIntervals
export subIntervalsToLP = subIntervalsToLP
export extendSubIntervalsWithValues = extendSubIntervalsWithValues
