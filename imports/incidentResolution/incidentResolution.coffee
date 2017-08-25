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
# The objective function minimizes the combined absolute values of the
# difference between the subinterval case rates and their associated incident
# case rates. Essentially, it tries to make the resolved rates fit the
# rates in the incident reports as closly as possible.

import LocationTree from './LocationTree.coffee'
import Solver from './LPSolver'

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
  incidents.forEach((incident, incidentId)->
    mainConstraintVars = []
    incidentSubs = IncidentToSELs[incidentId]
    if not incidentSubs
      console.log "Error: No subintervals for", incidentId
    MILLIS_PER_DAY = 1000 * 60 * 60 * 24
    incidentLength = (Number(incident.endDate) - Number(incident.startDate)) / MILLIS_PER_DAY
    incidentRate = incident.count / incidentLength
    for subInterval in incidentSubs
      { id, start, end } = subInterval
      itervalLengthDays = (end - start) / MILLIS_PER_DAY
      # The absIntervalId variables are the absolute value of the difference
      # between the subinterval's rate and the source incident's overall rate.
      # The objective function will attempt to minimize this quantity.
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
    "min: " + incidents.map((i, idx)-> "1 abs#{idx}").join(" ")
  ].concat(constraints)

extendSubIntervalsWithValues = (incidents, subIntervals)->
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

export intervalToEndpoints = intervalToEndpoints
export differentailIncidentsToSubIntervals = differentailIncidentsToSubIntervals
export subIntervalsToLP = subIntervalsToLP
export extendSubIntervalsWithValues = extendSubIntervalsWithValues
