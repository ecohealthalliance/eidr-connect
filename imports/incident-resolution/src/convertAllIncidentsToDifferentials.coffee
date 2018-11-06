LocationTree = require('./LocationTree')
regionToCountries = require('../regionToCountries.json')
countryISOToGeoname = require('../countryISOToGeoname.json')
DifferentialIncident = require('./DifferentialIncident')
_ = require('underscore')

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
