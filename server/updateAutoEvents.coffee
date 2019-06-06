import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'
import {capitalize} from '/imports/utils'
import diseaseToSubtypes from '/imports/diseaseToSubtypes.json'
import getCannonicalDiseaseURI from '/imports/getCannonicalDiseaseURI'

module.exports = ->
  startDate = moment().subtract(2, 'years').toDate()
  diseaseGroups = {}
  myIncidents = Incidents.find(
    'resolvedDisease.id': $exists: true
    'species.id': $exists: true
    deleted: $in: [null, false]
    'dateRange.end': $gte: startDate
  ).fetch().filter (incident) ->
    # Filter out non-human incidents because they have
    # a larger number of false-positives.
    incident.species.id == 'tsn:180092'
  myIncidents.forEach (incident) ->
    disease = incident.resolvedDisease
    disease.id = getCannonicalDiseaseURI(disease.id)
    if disease.id == 'http://purl.obolibrary.org/obo/DOID_0050117'
      # Do not create event for disease by infectious agent because it will
      # contain too many incidents.
      return
    diseaseGroups[disease.id + ":" + incident.species.id] = {
      resolvedDisease: disease
      species: incident.species
      incidentCount: 0
    }
  diseaseToParents = {}
  for id, diseaseGroup of diseaseGroups
    diseaseId = diseaseGroup.resolvedDisease.id
    (diseaseToSubtypes[diseaseId] or []).forEach (subtypeId) ->
      diseaseToParents[subtypeId] = (diseaseToParents[subtypeId] or []).concat([diseaseId])
  for key, value of diseaseToParents
    diseaseToParents[key] = value.sort((a, b) -> diseaseToSubtypes[a].length - diseaseToSubtypes[b].length)
  myIncidents.forEach (incident) ->
    disease = incident.resolvedDisease
    (diseaseToParents[disease.id] or []).concat([disease.id]).forEach (diseaseId) ->
      diseaseGroup = diseaseGroups[diseaseId + ":" + incident.species.id]
      if diseaseGroup
        if (incident.dateRange?.end and incident.dateRange.end > diseaseGroup.lastIncidentDate) or not diseaseGroup.lastIncidentDate
          diseaseGroup.lastIncidentDate = incident.dateRange.end
        diseaseGroup.incidentCount++
  for id, diseaseGroup of diseaseGroups
    disease = diseaseGroup.resolvedDisease
    species = diseaseGroup.species
    if capitalize(disease.text).startsWith('Human')
      eventName = capitalize(disease.text)
    else
      eventName = capitalize(if species.id is 'tsn:180092' then 'Human' else species.text)
      eventName += ' ' + capitalize(disease.text)
    parentDiseases = diseaseToParents[disease.id]
    AutoEvents.upsert 'diseases.id': disease.id,
      # The event disease's parent diseases sorted by position in the heirarchy
      # so the top disease comes last.
      # Note that only diseases with corresponding auto-events are included.
      # This is leveraged to determine whether parent events exist that contain
      # the cases of a given auto-event and prevent double counting.
      parentDiseases: parentDiseases
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
