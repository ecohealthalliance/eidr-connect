LocationTree = require('./LocationTree')
Solver = require('./LPSolver')
convertAllIncidentsToDifferentials = require('./convertAllIncidentsToDifferentials')
_ = require('underscore')

MILLIS_PER_DAY = 1000 * 60 * 60 * 24

# The resolver divides incidents into subintervals non-overlapping start and
# end points. Each sub-interval has only a single location, so several may
# be created for incidents with multiple locations. If incidents have the same
# date range and location, they will create only a single sub-interval.
# This is illustrated below where the incidents I1, I2 and I3 are divided into
# sub-intervals labeled A, B1, B2, C, D1, D2 and E:
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
class SubInterval
  constructor: (@id, @start, @end, @location, @incidentIds, @__value=null) ->
    @locationId = @location.id
    # The total number of cases that occured over the sub-interval.
    Object.defineProperty @, 'value',
      get: =>
        @__value
      enumerable: true
      configurable: true
    # The duration in days.
    Object.defineProperty @, 'duration',
      get: =>
        (@end - @start) / MILLIS_PER_DAY
      enumerable: true
      configurable: true
  setValue: (@__value) ->
    @rate = @__value / @duration
  setRate: (@rate) ->
    @__value = @rate * @duration

class Endpoint
  constructor: (@isStart, @offset, @interval) ->

intervalToEndpoints = (interval) ->
  if Number(interval.startDate) >= Number(interval.endDate)
    console.log interval
    throw new Error("Invalid interval: " + interval)
  [
    new Endpoint(true, Number(interval.startDate), interval)
    new Endpoint(false, Number(interval.endDate), interval)
  ]

differentialIncidentsToSubIntervals = (differentialIncidents) ->
  if differentialIncidents.length == 0
    return []
  endpoints = []
  locationsById = {}
  differentialIncidents.forEach (incident, idx) ->
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
  # maps intervals by their unique start-end-location to their overlapping incidents.
  SELToIncidents = {}
  # While iterating over the end-points, this tracks the intervals the current
  # endpoint overlaps.
  activeIntervals = [priorEndpoint.interval]
  endpoints.slice(1).forEach (endpoint) ->
    if priorEndpoint.offset != endpoint.offset
      # Ensure a subinterval is created for the top level locations between
      # every endpoint, even if no overlapping incident exists.
      # This makes it so time-series data is easier to extract to top level
      # locations since sub-locations don't need to be checked at points where
      # the value is undefined.
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
    SELs.push(new SubInterval(
      idx,
      parseInt(start),
      parseInt(end),
      locationsById[locationId],
      incidentIds
    ))
    idx++
  return SELs

# Use the given sub-intervals to formulate a linear programming problem.
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
    incidentRate = incident.count / incident.duration
    for subInterval in incidentSubs
      { id, start, end, duration } = subInterval
      # The absX variables are the absolute value of the max difference
      # between the subinterval's rate and the source incidents' overall rates.
      # The objective function will attempt to minimize this quantity.
      # Note: It might be simpler in some regards to create an absX variable for
      # each incident sub-interval pair so the differences are all minimized
      # rather than only the max difference. However, it would increase the
      # number of variables and it would give more weight to repeated incidents.
      constraints.push("#{(1 / duration).toFixed(12)} s#{id} -1 abs#{id} <= #{incidentRate}")
      constraints.push("#{(1 / duration).toFixed(12)} s#{id} 1 abs#{id} >= #{incidentRate}")
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
    s.setValue 0
  for key, value of solution
    if key.startsWith("s")
      subId = key.split("s")[1]
      subInterval = subIntervals[parseInt(subId)]
      subInterval.setValue value

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
# Toplological sorting is used to resolve the child location rates before
# their parent locations' rates.
extendSubIntervalsWithValuesTS = (differentialIncidents, subIntervals) ->
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
  differentialIncidents.forEach((incident, incidentId) ->
    incidentSubs = IncidentToSELs[incidentId]
    if not incidentSubs
      console.log "Error: No subintervals for", incidentId
    for subInterval in incidentSubs
      subIntervalRates[subInterval.id].push(incident.rate)
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
    {start, end, duration} = subInterval
    subInterval.setRate(subIntervalRates[subInterval.id])

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
extendSubIntervalsWithValues = (incidents, subIntervals, method="topologicalSort") ->
  if method is "topologicalSort"
    extendSubIntervalsWithValuesTS(incidents, subIntervals)
  else
    extendSubIntervalsWithValuesLP(incidents, subIntervals)

getContainedSubIntervals = (containingIncident, subIntsGroupedAndSortedByStart) ->
  overlappingSubInts = []
  for [start, subIntervalGroup] in subIntsGroupedAndSortedByStart
    if start < Number(containingIncident.startDate)
      continue
    if start >= Number(containingIncident.endDate)
      break
    overlappingSubInts = overlappingSubInts.concat(subIntervalGroup)
  overlappingSubInts.filter (subInt) ->
    LocationTree.locationContains(containingIncident.locations[0], subInt.location)

# Get the sub-intervals for the top-level locations in their location tree.
# This assumes there is no time interval where a top location has no value
# but one of its sub locations does. That is true for sub intervals created
# by differentialIncidentsToSubIntervals().
getTopLevelSubIntervals = (subInts) ->
  tree = LocationTree.from(subInts.map((x) -> x.location))
  subIntsByTimeIntervals = _.groupBy(subInts, (subInt) -> subInt.start + "," + subInt.end)
  locationToSubInts = _.groupBy(subInts, (subInt) -> subInt.location.id)
  tree.children.reduce((sofar, locationNode) ->
    sofar.concat(locationToSubInts[locationNode.value.id])
  , [])

# Remove incidents that cause the resolved number of cases to exceed
# the numbers given in the constraining incidents, cumulative incidents
# that are inconsistent, and incidents that far exceed the typical case rate.
removeOutlierIncidents = (originalIncidents, constrainingIncidents) ->
  nonAnalysableIncidents = []
  analysableIncidents = []
  originalIncidents.forEach (incident)->
    analysable = incident.dateRange and\
      (incident.cases or incident.deaths) > 0 and\
      incident.type != 'activeCount' and\
      incident.locations.length > 0
    if analysable
      analysableIncidents.push(incident)
    else
      nonAnalysableIncidents.push(incident)
  result = []
  diseases = _.chain(analysableIncidents)
    .map (x) -> x.resolvedDisease?.id
    .uniq()
    .value()
  diseases.forEach (disease) ->
    diseaseMatch = (x) -> x.resolvedDisease?.id == disease
    result = result.concat(
      removeOutlierIncidentsSingleDisease(
        analysableIncidents.filter(diseaseMatch),
        constrainingIncidents.filter(diseaseMatch))
    )
  return result.concat(nonAnalysableIncidents)

removeOutlierIncidentsSingleDisease = (originalIncidents, constrainingIncidents) ->
  incidents = convertAllIncidentsToDifferentials(originalIncidents)
  constrainingIncidents = convertAllIncidentsToDifferentials(constrainingIncidents.filter (incident)->
    not incident.min
  )
  # Incidents are partitioned so that confirmed incidents only constrain
  # confirmed incidents and deaths only constrain deaths
  partitions = {
    "cases": {
      "confirmed": []
      "unconfirmed": []
    }
    "deaths": {
      "confirmed": []
      "unconfirmed": []
    }
  }
  incidents.forEach (incident) ->
    status = if incident.status == "confirmed" then "confirmed" else "unconfirmed"
    partitions[incident.type][status].push incident
  resultingIncidents = []
  resultingIncidents = removeOutlierIncidentsSingleType(
    resultingIncidents.concat(partitions["deaths"]["confirmed"]),
    constrainingIncidents)
  resultingDeaths = removeOutlierIncidentsSingleType(
    resultingIncidents.concat(partitions["deaths"]["unconfirmed"]),
    constrainingIncidents.filter (x) -> x.status != "confirmed")
  resultingConfirmed = removeOutlierIncidentsSingleType(
    resultingIncidents.concat(partitions["cases"]["confirmed"]),
    constrainingIncidents.filter (x) -> x.type == "cases")
  resultingIncidents = removeOutlierIncidentsSingleType(
    _.union(resultingDeaths, resultingConfirmed, partitions["cases"]["unconfirmed"]),
    constrainingIncidents.filter (x) -> x.type == "cases" and x.status != "confirmed")
  return _.chain(resultingIncidents)
    .filter (x) -> not x.__virtualIncident
    .pluck('originalIncidents')
    .flatten(true)
    .value()

# This is the core of the outlier incident remove routine.
# It is designed to work only on a single type of differential,
# so the calling removeOutlierIncidents function must
# convert the original incidents into differential incidents and parition
# them into the correct groups.
removeOutlierIncidentsSingleType = (incidents, constrainingIncidents) ->
  # Remove incidents that exceed the 90th percentile of rates for their feature
  # type by more than 10x.
  incidentsByLocationId = _.groupBy(incidents, (x) -> x.locations[0].id)
  myLocationTree = LocationTree.from(incidents.map (x) -> x.locations[0])
  locationIdToParent = myLocationTree.makeIdToParentMap()
  nodeLayer = myLocationTree.children
  while nodeLayer.length > 0
    nextLayer = []
    nodeLayer.forEach (node) ->
      nextLayer = nextLayer.concat(node.children)
      locationId = node.value.id
      incidentGroup = incidentsByLocationId[locationId]
      loop
        if incidentGroup.length >= 10
          sortedIncidents = _.sortBy(incidentGroup, 'rate')
          idx90thPercentile = Math.floor((sortedIncidents.length - 1) * .9)
          incident90thPercentile = sortedIncidents[idx90thPercentile]
          incidentsToKeep = sortedIncidents.slice(0, idx90thPercentile)
          sortedIncidents.slice(idx90thPercentile).forEach (incident) ->
            if incident.rate < incident90thPercentile.rate * 10
              incidentsToKeep.push(incident)
          incidentsByLocationId[node.value.id] = incidentsToKeep
          break
        parent = locationIdToParent[locationId]
        if parent.value == 'ROOT'
          break
        else
          locationId = parent.value.id
          incidentGroup = incidentGroup.concat(incidentsByLocationId[locationId])
    nodeLayer = nextLayer
  incidents = _.chain(incidentsByLocationId)
    .values()
    .flatten(true)
    .uniq()
    .value()
  # Create constraining incidents from differences in cumulative incidents + 30%
  # A hightened threshold is used to account for error in cumulative incident
  # counts.
  # A constraining incidents may cause the cumulative incident it was created
  # from to be removed as an outlier. This behaviour may be suprising, but it
  # is intentional. If a cumulative incident contains incidents that exceed
  # its case rate for even short intervals, then the sum of the resolved cases
  # over the duration of the cumulative incident will be greater than the
  # number of cases specified by the incident. It is likely that short duration
  # incidents contained by the cumulative incident provide a higher granularily
  # accounting of the cases that occurred, so using them rather than the
  # cumulative incident can make sense as long as they have lower CASIM scores
  # (see CASIM definition below).
  constrainingIncidents = constrainingIncidents.concat(
    incidents
      .filter (x) -> x.cumulative and x.count >= 1
      .map (x) ->
        result = Object.create(x)
        result.count = Math.floor(x.count * 1.3)
        result
  )
  # When a constraining incident has more than one location this creates a
  # a clone of it with each location as the only location.
  # This makes the constraint weaker since the combined counts at all locations
  # could exceed the count given in the incident. The planned uses of
  # constrainting incidents involve only single location incidents, so handling
  # multiple location incidents in the optimal way is not a priority.
  constrainingIncidents = _.chain(constrainingIncidents)
    .map (x) ->
      x.locations.map (loc) ->
        y = Object.create(x)
        y.locations = [loc]
        y
    .flatten()
    .value()
  # Mix in constraining incidents with counts set to zero so the sub-interval
  # bounds align with the constraining incidents. Counts are set to zero
  # so they do not alter the resolved count.
  incidents = incidents.concat(constrainingIncidents.map (x) ->
    x.clone
      count: 0
      __virtualIncident: true
  )
  # Iteratively remove incidents until the constraining incidents are not
  # exceeded or the iteration limit is exceeded.
  iteration = 0
  while incidents.length > 0 and iteration < 3
    outlierIncidentIds = new Set()
    subIntervals = differentialIncidentsToSubIntervals(incidents)
    # Compute CASIM for each sub-interval
    # CASIM = count above sub-interval median
    # The "lower" median is used so we have an upper bound on the cases that
    # will be removed by removing the incident. The median is "lower" in that
    # if the size of the set is even, the smaller of the middle values is used
    # rather than their mid-point.
    subIntervals.forEach (subInt) ->
      { start, end, incidentIds, duration } = subInt
      valuesByIncident = {}
      for incidentId in incidentIds
        incident = incidents[incidentId]
        # Exclude virtual incidents from the incident value distribution.
        if incident.__virtualIncident
          continue
        valuesByIncident[incidentId] = incident.rate * duration
      values = _.values(valuesByIncident).concat([0])
      sortedValues = values.sort()
      lowerMedian = sortedValues[Math.ceil(values.length / 2) - 1]
      subInt.__valuesByIncident = valuesByIncident
      subInt.__CASIMByIncident = _.object(
        [k, Math.max(0, v - lowerMedian)] for k, v of valuesByIncident
      )
      # The marginal value of an incident is the difference between it's value
      # and the next largest incident value.
      # It is greater than or equal to the the amount the resolved value would
      # decrease if the incident were removed (after all the greater incidents).
      # It is not necessarily equal because the overlapping incidents 
      # for child locations are not factored in.
      subInt.__marginalValueByIncident = _.object(
        [k, v - sortedValues[sortedValues.indexOf(v) - 1]] for k, v of valuesByIncident
      )
    extendSubIntervalsWithValues(incidents, subIntervals)
    subIntsByStart = _.chain(subIntervals)
      .groupBy('start')
      .pairs()
      .map ([start, subIntGroup]) -> [parseInt(start), subIntGroup]
      .sortBy (x) -> x[0]
      .value()
    excessCounts = 0
    constrainingIncidents.forEach (cIncident) ->
      # Compute a resolved count for sub-intervals that occur at a time/location
      # that overlaps the constraining incident.
      # If it exceeds the constraining incident, remove the incidents with
      # the highest CASIM values.
      containedSubInts = getContainedSubIntervals(cIncident, subIntsByStart)
      resolvedSum = sum(getTopLevelSubIntervals(containedSubInts).map (subInt) -> subInt.value)
      difference = resolvedSum - cIncident.count
      if difference > 0
        excessCounts += 1
        if iteration == 0
          # Remove incidents that have values exceeding the constraining incident.
          incidentToTotalValue = {}
          for subInterval in containedSubInts
            for incidentId, value of subInterval.__valuesByIncident
              incidentToTotalValue[incidentId] = (incidentToTotalValue[incidentId] || 0) + value
          incidentsRemoved = false
          for incidentId, value of incidentToTotalValue
            if value > cIncident.count
              outlierIncidentIds.add(parseInt(incidentId))
              incidentsRemoved = true
          if incidentsRemoved
            return
        # Remove incidents until the total CASIM of the removed incidents
        # is greater than or equal to the excess resolved count.
        # Since many incidents could cause the resolved count to exceed
        # the constraining incident's count, removing the top incidents
        # won't necessariliy fix the constraint violation. That is why
        # this process is looped until there are no longer any excess cases
        # in the resolved counts.
        incidentToTotalCASIM = {}
        incidentToMarginalValue = {}
        for subInterval in containedSubInts
          for incidentId, value of subInterval.__CASIMByIncident
            incidentToTotalCASIM[incidentId] = (incidentToTotalCASIM[incidentId] || 0) + value
            incidentToMarginalValue[incidentId] = (
              incidentToMarginalValue[incidentId] || 0
            ) + subInterval.__marginalValueByIncident[incidentId]
        incidentsSortedByCASIM = _.chain(incidentToTotalCASIM)
          .pairs()
          .map ([k, v]) -> [parseInt(k), v]
          .sortBy (x) -> -x[1]
          .map (x) -> x[0]
          .value()
        marginalValueRemoved = 0
        for incidentId in incidentsSortedByCASIM
          outlierIncidentIds.add(incidentId)
          marginalValueRemoved += incidentToMarginalValue[incidentId]
          if marginalValueRemoved >= difference
            break
    if excessCounts == 0
      break
    incidents = incidents.filter (x) -> not outlierIncidentIds.has(x.id)
    iteration++
  return incidents

# Merge adjacent sub-intervals.
mergeSubIntervals = (subIntervals) ->
  subIntervals.reduce (sofar, subInterval) ->
    prev = sofar.slice(-1)[0]
    if prev and prev.end == subInterval.start
      prev.end = subInterval.end
      sofar
    else
      sofar.concat(Object.create(subInterval))
  , []

# Create new differential incidents that when resolved with the original
# incidents will produce counts equal to the target incidents.
createSupplementalIncidents = (incidents, targetIncidents) ->
  result = []
  diseases = _.chain(incidents.concat(targetIncidents))
    .map (x) -> x.resolvedDisease?.id
    .uniq()
    .value()
  diseases.forEach (disease) ->
    diseaseMatch = (x) -> x.resolvedDisease?.id == disease
    result = result.concat(
      createSupplementalIncidentsSingleDisease(
        incidents.filter(diseaseMatch),
        targetIncidents.filter(diseaseMatch))
    )
  return result

createSupplementalIncidentsSingleDisease = (incidents, targetIncidents) ->
  incidents = convertAllIncidentsToDifferentials(incidents)
  targetIncidents = convertAllIncidentsToDifferentials(targetIncidents.filter (incident)->
    not incident.max
  )
  return createSupplementalIncidentsSingleType(
    _.where(incidents, type: "cases"),
    _.where(targetIncidents, type: "cases")
  ).concat(
    createSupplementalIncidentsSingleType(
      _.where(incidents, type: "deaths"),
      _.where(targetIncidents, type: "deaths")
    )
  )

createSupplementalIncidentsSingleType = (incidents, targetIncidents) ->
  supplementalIncidents = []
  incidents = incidents.concat(targetIncidents.map (x) ->
    x.clone(
      count: 0
      __virtualIncident: true
    )
  )
  subIntervals = differentialIncidentsToSubIntervals(incidents)
  extendSubIntervalsWithValues(incidents, subIntervals)
  subIntsByStart = _.chain(subIntervals)
    .groupBy('start')
    .pairs()
    .map ([start, subIntGroup]) -> [parseInt(start), subIntGroup]
    .sortBy (x) -> x[0]
    .value()
  targetIncidents.forEach (targetIncident) ->
    containedSubInts = getContainedSubIntervals(targetIncident, subIntsByStart)
    # Create sub-intervals to fill any gaps between the start and end of the
    # target incident and the sub-intervals it contains.
    supplementedSubIntervals = []
    if containedSubInts.length == 0
      targetIncident.locations.forEach (TILocation)->
        supplementedSubIntervals.push(new SubInterval(
          Number(targetIncident.startDate),
          Number(targetIncident.endDate),
          [TILocation],
          [targetIncident._id],
          targetIncident.count / targetIncident.locations.length
        ))
    else
      firstStartDate = _.max(containedSubInts, (s)->Number(s.endDate))
      if Number(targetIncident.startDate) < firstStartDate
        targetIncident.locations.forEach (TILocation)->
          supplementedSubIntervals.push(new SubInterval(
            Number(targetIncident.startDate),
            firstStartDate,
            [TILocation],
            [targetIncident._id],
            0
          ))
      lastEndDate = _.min(containedSubInts, (s)->Number(s.startDate))
      if Number(targetIncident.endDate) > lastEndDate
        targetIncident.locations.forEach (TILocation)->
          supplementedSubIntervals.push(new SubInterval(
            lastEndDate,
            Number(targetIncident.endDate),
            [TILocation],
            [targetIncident._id],
            0
          ))
    containedTopLevelSubIntervals = getTopLevelSubIntervals(containedSubInts)
    resolvedSum = sum(containedTopLevelSubIntervals.map (subInt) -> subInt.value)
    remainingCountDifference = targetIncident.count - resolvedSum
    if remainingCountDifference <= 0
      return
    # Supplemental incidents are added by increasing the rates at the lowest
    # sub-intervals until there is not difference in counts between the
    # target incident and resolved sub-intervals. This similar to filling up a
    # a pool where the water is the supplemental incidents and the floor
    # rate is its level.
    subIntsSortedByRate = _.sortBy(containedTopLevelSubIntervals, 'rate')
    floorRate = 0
    for [subInt, nextSubInt] in _.zip(subIntsSortedByRate, subIntsSortedByRate.slice(1))
      supplementedSubIntervals.push(subInt)
      totalNewSubIntDuration = sum(supplementedSubIntervals.map (supSubInt) -> supSubInt.duration)
      if not nextSubInt
        floorRate += remainingCountDifference / totalNewSubIntDuration
        break
      nextRateDifference = nextSubInt.rate - subInt.rate
      if nextRateDifference * totalNewSubIntDuration >= remainingCountDifference
        floorRate += remainingCountDifference / totalNewSubIntDuration
        break
      else
        remainingCountDifference -= nextRateDifference * totalNewSubIntDuration
        floorRate = nextSubInt.rate
    if floorRate > 0
      supplementalIncidents = supplementalIncidents.concat(
        mergeSubIntervals(supplementedSubIntervals).map (subInt) ->
          {start, end, duration} = subInt
          targetIncident.clone
            count: floorRate * duration
            startDate: new Date(start)
            endDate: new Date(end)
      )
  return supplementalIncidents

sum = (list) ->
  list.reduce((sofar, x) ->
    sofar + x
  , 0)

enumerateDateRange = (start, end) ->
  current = new Date(start)
  end = new Date(end)
  result = []
  while current < end
    result.push(new Date(current))
    current.setUTCDate(current.getUTCDate() + 1)
    current = new Date(current.toISOString().split('T')[0])
  return result

subIntervalsToDailyRates = (subIntervals) ->
  dailyRates = {}
  subIntervals.forEach (subInterval)->
    enumerateDateRange(subInterval.start, subInterval.end).forEach (date) ->
      day = date.toISOString().split('T')[0]
      dailyRates[day] = (dailyRates[day] or 0) + subInterval.rate
  _.sortBy(_.pairs(dailyRates), (x) -> x[0])

dailyRatesToActiveCases = (dailyRates, dailyDecayRate, dateWindow) ->
  startDate = new Date(dateWindow.startDate).toISOString().split('T')[0]
  activeCases = 0
  firstRateDay = if dailyRates.length > 0 then dailyRates[0][0] else startDate
  dailyRates = _.object(dailyRates)
  activeCasesByDay = enumerateDateRange(
    # If the daily rates go outside of the date window, we still iterate over
    # them to determine the initial active cases on the first day of the
    # date window.
    Math.min(new Date(startDate), new Date(firstRateDay)),
    dateWindow.endDate
  ).map (date) ->
    day = date.toISOString().split('T')[0]
    rate = dailyRates[day] or 0
    activeCases = activeCases * dailyDecayRate + rate
    [day, activeCases]
  .filter ([day, noop]) ->
    day >= startDate

subIntervalsToActiveCases = (subIntervals, dailyDecayRate, dateWindow) ->
  dailyRatesToActiveCases(subIntervalsToDailyRates(subIntervals), dailyDecayRate, dateWindow)

mapLocationsToMaxSubIntervals = (locationTree, subIntervals) ->
  locToSubintervals = {}
  for location in locationTree.locations()
    locToSubintervals[location.id] = []
  for location in locationTree.locations()
    for subInterval in subIntervals
      subLocation = subInterval.location
      if LocationTree.locationContains(location, subLocation)
        locToSubintervals[location.id].push(subInterval)
  return _.chain(locToSubintervals)
    .pairs()
    .map ([locId, locSubIntervals]) =>
      location = locationTree.getLocationById(locId)
      groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
      maxSubintervals = []
      for group, subIntervalGroup of groupedLocSubIntervals
        subIntervalGroupTree = LocationTree.from(subIntervalGroup.map (x) -> x.location)
        subIntervalGroupTree.children.forEach (locationNode) ->
          maxSubintervals.push(_.max(subIntervalGroup, (subInterval) ->
            if locationNode.value.id == subInterval.location.id
              subInterval.value
            else
              0
          ))
      return [locId, maxSubintervals]
    .object()
    .value()

module.exports = {
  intervalToEndpoints: intervalToEndpoints
  differentialIncidentsToSubIntervals: differentialIncidentsToSubIntervals
  subIntervalsToLP: subIntervalsToLP
  extendSubIntervalsWithValues: extendSubIntervalsWithValues
  removeOutlierIncidents: removeOutlierIncidents
  createSupplementalIncidents: createSupplementalIncidents
  subIntervalsToActiveCases: subIntervalsToActiveCases
  dailyRatesToActiveCases: dailyRatesToActiveCases
  subIntervalsToDailyRates: subIntervalsToDailyRates
  enumerateDateRange:  enumerateDateRange
  mapLocationsToMaxSubIntervals: mapLocationsToMaxSubIntervals
  convertAllIncidentsToDifferentials: convertAllIncidentsToDifferentials
  LocationTree: LocationTree
}
