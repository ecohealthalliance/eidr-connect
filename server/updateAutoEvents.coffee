import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'
import {capitalize} from '/imports/utils'

module.exports = ->
  startDate = moment().subtract(2, 'years').toDate()
  diseaseGroups = {}
  Incidents.find(
    'resolvedDisease.id': $exists: true
    'species.id': $exists: true
    deleted: $in: [null, false]
    'dateRange.end': $gte: startDate
  ).forEach (incident) ->
    # Filter out non-human incidents because they have
    # a larger number of false-positives.
    if incident.species.id != 'tsn:180092'
      return
    disease = incident.resolvedDisease
    key = disease.id + ":" + incident.species.id
    diseaseGroup = diseaseGroups[key] or {
      resolvedDisease: disease
      species: incident.species
      incidentCount: 0
    }
    if incident.dateRange.end > diseaseGroup.lastIncidentDate or not diseaseGroup.lastIncidentDate
      diseaseGroup.lastIncidentDate = incident.dateRange.end
    diseaseGroup.incidentCount++
    diseaseGroups[key] = diseaseGroup
  for id, diseaseGroup of diseaseGroups
    disease = diseaseGroup.resolvedDisease
    species = diseaseGroup.species
    if capitalize(disease.text).startsWith('Human')
      eventName = capitalize(disease.text)
    else
      eventName = capitalize(if species.id is 'tsn:180092' then 'Human' else species.text)
      eventName += ' ' + capitalize(disease.text)
    AutoEvents.upsert 'diseases.id': disease.id,
      eventName: eventName
      diseases: [disease]
      species: [species]
      lastIncidentDate: diseaseGroup.lastIncidentDate
      incidentCount: diseaseGroup.incidentCount
      # filter out incidents that appear to have invalid dates
      dateRange:
        start: startDate
  # Remove AutoEvents without any incidents:
  AutoEvents.find().forEach (event)->
    key = event.diseases?[0].id + ":" + event.species?[0].id
    if key not of diseaseGroups
      AutoEvents.remove(event)
