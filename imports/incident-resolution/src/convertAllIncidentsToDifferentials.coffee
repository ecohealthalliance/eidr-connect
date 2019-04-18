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

class SortedIncidentSequence
  constructor: (@finalIncident, @priorIncidentSeq=null) ->
    @finalCount = @finalIncident.count
    @score = 1
    if @priorIncidentSeq
      @score = @priorIncidentSeq.score
      valueDifference = @finalCount - @priorIncidentSeq.finalCount
      if valueDifference < 0
        # TODO: The scoring criteria for resets could be improved.
        # The problem with this criteria is that a series of 6 small values
        # could be inserted between a pair of points in a series of large values.
        @score -= 4
      else
        @score += 1
  concat: (newIncident) ->
    new SortedIncidentSequence(newIncident, @)
  getIncidents: () ->
    if @priorIncidentSeq
      @priorIncidentSeq.getIncidents().concat(@finalIncident)
    else
      [@finalIncident]

# Find the sequence of cumulative incidents with the optimal score.
# The score is determined by the number of incidents in montonically increasing
# sequences, and the number of times the overall sequence restarts.
# Adding incidents increases the score and restarting reduces the score.
computeOptimalCumulativeIncidentSequence = (cumulativeIncidents) ->
  # Sorted in descending order
  incidentSeqsSortedByScore = []
  cumulativeIncidents.forEach (cumulativeIncident)->
    noSmallerIncident = true
    for index in _.range(incidentSeqsSortedByScore.length)
      # Invididual incident sets are sorted chronologically.
      incidentSeq = incidentSeqsSortedByScore[index]
      finalCount = incidentSeq.finalCount
      if cumulativeIncident.count >= finalCount
        oneIfEqual = if cumulativeIncident.count == finalCount then 1 else 0
        greaterIncidentSeqs = incidentSeqsSortedByScore.slice(0, index)
        lesserIncidentSeqs = incidentSeqsSortedByScore.slice(index + oneIfEqual)
        extendedIncidentSeq = incidentSeq.concat(cumulativeIncident)
        resetIncidentSeq = incidentSeqsSortedByScore[0].concat(cumulativeIncident)
        if extendedIncidentSeq.score < resetIncidentSeq.score
          extendedIncidentSeq = resetIncidentSeq
        # index of where the greater incident sets end
        greaterIncidentSeqIndex = 0
        for greaterIncidentSeq in greaterIncidentSeqs
          if greaterIncidentSeq.score < extendedIncidentSeq.score
            break
          greaterIncidentSeqIndex += 1
        incidentSeqsSortedByScore = greaterIncidentSeqs
          .slice(0, greaterIncidentSeqIndex)
          .concat([extendedIncidentSeq])
          .concat(lesserIncidentSeqs)
        noSmallerIncident = false
        break
    if noSmallerIncident
      incidentSeqsSortedByScore = incidentSeqsSortedByScore
        .concat([new SortedIncidentSequence(cumulativeIncident)])
  return incidentSeqsSortedByScore[0].getIncidents()

computeSimpleCumulativeIncidentSequence = (incidentGroup) ->
  prevIncident = incidentGroup[0]
  result = [prevIncident]
  for [incident, nextIncident] in _.zip(incidentGroup.slice(1), incidentGroup.slice(2))
    countDifference = incident.count - prevIncident.count
    if countDifference < 0
      if nextIncident and nextIncident.count < prevIncident.count
        # The next next two count are less than the previous count
        # so assume the cumulative counts have started over.
        null
      else
        # otherwise assume the current incident is an outlier and skip it.
        continue
    result.push(incident)
    prevIncident = incident
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
      filteredCumulateIncidents = computeOptimalCumulativeIncidentSequence(incidentGroup)
      for [prevIncident, incident] in _.zip(filteredCumulateIncidents.slice(0, -1), filteredCumulateIncidents.slice(1))
        countDifference = incident.count - prevIncident.count
        if countDifference >= 0
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
          differentialIncidents.push(newDifferential)
  return differentialIncidents

module.exports = convertAllIncidentsToDifferentials
