import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'

module.exports = ->
  diseaseGroups = {}
  Incidents.find('resolvedDisease.id': $exists: true).forEach (i) ->
    disease = i.resolvedDisease
    diseaseGroup = diseaseGroups[disease.id] or {
      resolvedDisease: disease
      incidentCount: 0
    }
    if i.dateRange.end > diseaseGroup.lastIncidentDate or not diseaseGroup.lastIncidentDate
      diseaseGroup.lastIncidentDate = i.dateRange.end
    diseaseGroup.incidentCount++
    diseaseGroups[disease.id] = diseaseGroup
  for id, diseaseGroup of diseaseGroups
    disease = diseaseGroup.resolvedDisease
    AutoEvents.upsert 'diseases.id': disease.id,
      eventName: disease.text
      diseases: [disease]
      lastIncidentDate: diseaseGroup.lastIncidentDate
      incidentCount: diseaseGroup.incidentCount
      # filter out incidents that appear to have invalid dates
      dateRange:
        start: new Date("1950-1-1")
