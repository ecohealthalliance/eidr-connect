# Code for updating the database on startup
import UserEvents from '/imports/collections/userEvents.coffee'
import incidentReportSchema from '/imports/schemas/incidentReport.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import GeonameSchema from '/imports/schemas/geoname.coffee'
import articleSchema from '/imports/schemas/article.coffee'
import Articles from '/imports/collections/articles.coffee'
import CuratorSources from '/imports/collections/curatorSources'
import Feeds from '/imports/collections/feeds'
import Constants from '/imports/constants.coffee'
import { regexEscape } from '/imports/utils'

DATA_VERSION = 21
AppMetadata = new Meteor.Collection('appMetadata')
priorDataVersion = AppMetadata.findOne(property: "dataVersion")?.value

geonamesById = {}
getGeonameById = (id)->
  if id of geonamesById
    return geonamesById[id]
  geonamesResult = HTTP.get Constants.GRITS_URL + '/api/geoname_lookup/api/geonames',
    params:
      ids: [id]
  geoname = geonamesResult.data.docs[0]
  if not geoname
    geonamesById[id] = null
    return
  geonamesById[id] = GeonameSchema.clean(geoname)
  return geonamesById[id]

module.exports = ->
  if priorDataVersion and priorDataVersion >= DATA_VERSION
    return
  console.log "Running database update code..."

  console.log "Updating events with unmarked cumulative counts..."
  UserEvents.find(creationDate: $lte: new Date("Dec 1 2016")).map (event) ->
    incidents = Incidents.find _id: $in: _.pluck(event.incidents, "id")
    incidents.map (incident) ->
      if incident.dateRange.cumulative
        return
      if incident.modifiedDate
        return
      lengthMillis = Number(new Date(incident.dateRange.end)) - Number(new Date(incident.dateRange.start))
      lengthDays = lengthMillis / 1000 / 60 / 60 / 24
      if lengthDays > 1.1
        return
      if incident.cases > 50 or incident.deaths > 50
        incident.dateRange.cumulative = true
        incident.modifiedByUserId = null
        incident.modifiedByUserName = "database update script"
        incident.modifiedDate = new Date()
        Incidents.update(_id: incident._id, incident)

  console.log "Removing incidents with invalid dates..."
  invalidDateIncidents = []
  Incidents.find().map (incident) ->
    if incident.dateRange.end < incident.dateRange.start
      invalidDateIncidents.push(incident._id)
  console.log "Removing #{invalidDateIncidents.length} incidents"
  Incidents.remove(_id: $in: invalidDateIncidents)

  console.log 'Removing articles with invalid urls'
  Articles.find(
    url: /^([^\.]*|promedmail\.org\/post\/undefined)$/
  ).forEach (art) ->
    Articles.remove(_id: art._id)

  console.log 'Disassociating deleted incidents from events...'
  incidentCount = 0
  UserEvents.find().forEach (event) ->
    event.incidents?.forEach (i) ->
      incident = Incidents.findOne(i.id)
      if not incident or incident.deleted
        incidentCount++
        UserEvents.update event._id,
          $pull:
            incidents:
              id: i.id
  console.log "#{incidentCount} incidents disassociated"

  console.log 'Updating feeds - setting promed as default...'
  Feeds.update url: 'promedmail.org/post/',
    $set: default: true

  console.log "Adding incident types..."
  Incidents.update({
    type: $exists: false
    cases: $gte: 0
    'dateRange.cumulative': $in: [null, false]
  }, {
    $set: type: 'caseCount'
  }, multi: true)
  Incidents.update({
    type: $exists: false
    deaths: $gte: 0
    'dateRange.cumulative': $in: [null, false]
  }, {
    $set: type: 'deathCount'
  }, multi: true)
  Incidents.update({
    type: $exists: false
    cases: $gte: 0
    'dateRange.cumulative': true
  }, {
    $set: type: 'cumulativeCaseCount'
  }, multi: true)
  Incidents.update({
    type: $exists: false
    deaths: $gte: 0
    'dateRange.cumulative': true
  }, {
    $set: type: 'cumulativeDeathCount'
  }, multi: true)
  Incidents.update({
    type: $exists: false
    specify: $exists: true
    'dateRange.cumulative': true
  }, {
    $set: type: 'specify'
  }, multi: true)

  console.log 'Resolving known user specified diseases'
  Incidents.update({
    'resolvedDisease.id': "userSpecifiedDisease:Hand, Foot, and Mouth Disease"
  }, {
    $set:
      'resolvedDisease.id': 'http://purl.obolibrary.org/obo/DOID_10881'
      'resolvedDisease.text': 'hand, foot and mouth disease'
  }, multi: true)
  Incidents.update({
    'resolvedDisease.id': "userSpecifiedDisease:MERS-CoV"
  }, {
    $set:
      'resolvedDisease.id': 'https://www.wikidata.org/wiki/Q16654806'
      'resolvedDisease.text': 'Middle East respiratory syndrome'
  }, multi: true)
  Incidents.update({
    'resolvedDisease.id': "userSpecifiedDisease:Lasa Fever"
  }, {
    $set:
      'resolvedDisease.id': 'http://purl.obolibrary.org/obo/DOID_9537'
      'resolvedDisease.text': 'Lassa fever'
  }, multi: true)

  console.log 'Updating incidents - removing extra location properties...'
  Incidents.find('locations.rawNames': $exists: true).forEach (i) ->
    i.locations.forEach (l) ->
      delete l.alternateNames
      delete l.rawNames
      delete l.asciiName
      delete l.cc2
      delete l.elevation
      delete l.dem
      delete l.timezone
      delete l.modificationDate
    Incidents.update i._id, i

  AppMetadata.upsert({property: "dataVersion"}, $set: {value: DATA_VERSION})
  console.log "database update complete"
