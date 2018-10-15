import LocationTree from './LocationTree'
import regionToCountries from '/imports/regionToCountries.json'
import countryISOToGeoname from '/imports/countryISOToGeoname.json'

MILLIS_PER_DAY = 1000 * 60 * 60 * 24

class DifferentialIncident
  constructor: (incident) ->
    # Check if the incident has all the properties needed to define a
    # differential incident. If not default to converting a regular
    # incident.
    properties = [
      'startDate',
      'endDate',
      'count',
      'type',
      'locations',
      'cumulative',
      'originalIncidents'
    ]
    if properties.every((p) -> p of incident)
      for prop in properties
        @[prop] = incident[prop]
    else
      @startDate = new Date(incident.dateRange.start)
      @startDate.setUTCHours(0)
      @startDate.setUTCMinutes(0)
      @startDate.setUTCSeconds(0)
      @startDate.setUTCMilliseconds(0)
      # Give the endDate a one hour offset before rounding it down to the start
      # of the day incase it is right before the end of the day.
      @endDate = new Date(incident.dateRange.end)
      @endDate.setUTCMinutes(70)
      @endDate.setUTCHours(0)
      @endDate.setUTCMinutes(0)
      @endDate.setUTCSeconds(0)
      @endDate.setUTCMilliseconds(0)
      if @startDate > @endDate
        console.log(incident)
        throw new Error("Invalid incident: Dates out of order.")
      else if Number(@startDate) == Number(@endDate) and not incident.dateRange.cumulative
        # Convert single day incidents to one day long date ranges
        @endDate.setUTCDate(@endDate.getUTCDate() + 1)
      @count = incident.cases or incident.deaths
      @type = _.keys(_.pick(incident, 'cases', 'deaths'))[0]
      # Remove duplicate/contained locations from location array
      @locations = LocationTree.from(incident.locations or []).children.map (x) ->
        x.value
      @cumulative = incident.dateRange.cumulative
      @originalIncidents = [incident]
    @initialize()
  initialize: () ->
    @duration = (Number(@endDate) - Number(@startDate)) / MILLIS_PER_DAY
    # The case rate is divided by the number of locations in the incident
    # so that a report of cases distributed in 3 states won't result in
    # a count of triple that for the country.
    @rate = @count / @duration / @locations.length
    @diseaseId = @originalIncidents[0].resolvedDisease?.id
    return @
  truncated: (dateRange) ->
    newStartDate = new Date(@startDate)
    newEndDate = new Date(@endDate)
    if @startDate < dateRange.start
      newStartDate = new Date(dateRange.start)
    if @endDate > dateRange.end
      newEndDate = new Date(dateRange.end)
    newDuration = (Number(newEndDate) - Number(newStartDate)) / MILLIS_PER_DAY
    @clone({
      startDate: newStartDate
      endDate: newEndDate
      count: @count * newDuration / @duration
    })
  clone: (extendProps={}) ->
    clonedIncident = Object.create(@)
    _.extend(clonedIncident, extendProps)
    clonedIncident.initialize()

# Replace cumulative incident reports with differential incident reports
# created by taking the difference in counts between two subsequent cumulative
# reports in the same location.
convertAllIncidentsToDifferentials = (incidents, replaceRegionsWithCountries=true) ->
  result = []
  diseases = _.chain(incidents)
    .map (x) -> x.resolvedDisease?.id
    .uniq()
    .value()
  diseases.forEach (disease) ->
    diseaseMatch = (x) -> x.resolvedDisease?.id == disease
    result = result.concat(
      convertAllIncidentsToDifferentialsSingleDisease(
        incidents.filter(diseaseMatch),
        replaceRegionsWithCountries)
    )
  return result

convertAllIncidentsToDifferentialsSingleDisease = (incidents, replaceRegionsWithCountries) ->
  cumulativeIncidents = []
  differentialIncidents = []
  # Replace regions with contained country geonames
  if replaceRegionsWithCountries
    incidents.forEach (incident) ->
      if not incident.locations?.length
        return
      locations = []
      incident.locations.forEach (location) ->
        if regionToCountries[location.id]
          regionToCountries[location.id].countryISOs.forEach (iso) ->
            console.assert(countryISOToGeoname[iso])
            locations.push(countryISOToGeoname[iso])
        else
          locations.push(location)
      incident.locations = locations
  incidents.forEach (incident) ->
    if not incident.dateRange
      return
    if (incident.type in ['activeCount', 'specify']) or incident.specify
      return
    simpleIncident = new DifferentialIncident(incident)
    if not simpleIncident.count
      return
    if incident.dateRange.cumulative
      cumulativeIncidents.push(simpleIncident)
    else
      differentialIncidents.push(simpleIncident)
  _.chain(cumulativeIncidents)
    .sortBy("endDate")
    .groupBy (i) ->
      i.type + "," + (i?.locations or []).map((l) -> l.id).sort()
    .forEach (incidentGroup, b) ->
      # If two incidents have the same time offset, use the one with the
      # greater count.
      incidentGroup = incidentGroup.reduce((sofar, incident)->
        if sofar.length == 0
          return [incident]
        prevIncident = sofar.slice(-1)[0]
        dateDiff = Number(incident.endDate) - Number(prevIncident.endDate)
        if dateDiff > 0
          return sofar.concat(incident)
        else if dateDiff == 0
          if prevIncident.count >= incident.count
            return sofar
          else
            return sofar.slice(0, -1).concat(incident)
        else
          throw Error("endDates are not sorted.")
      , [])
      prevIncident = incidentGroup[0]
      for [incident, nextIncident] in _.zip(incidentGroup.slice(1), incidentGroup.slice(2))
        countDifference = incident.count - prevIncident.count
        if countDifference < 0
          # This cumulative count is less than prior counts.
          # A differential count cannot be created from it.
          if nextIncident and nextIncident.count < prevIncident.count
            # The next next two count are less than the previous count
            # so assume the cumulative counts have started over.
            prevIncident = incident
          continue
        newDifferential = new DifferentialIncident(
          type: incident.type
          locations: incident.locations
          cumulative: incident.cumulative
          count: countDifference
          startDate: prevIncident.endDate
          endDate: incident.endDate
          originalIncidents: prevIncident.originalIncidents.concat(
            incident.originalIncidents
          )
        )
        prevIncident = incident
        differentialIncidents.push(newDifferential)
  return differentialIncidents

module.exports = convertAllIncidentsToDifferentials
