# Code for updating the database on startup
import UserEvents from '/imports/collections/userEvents.coffee'
import incidentReportSchema from '/imports/schemas/incidentReport.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import GeonameSchema from '/imports/schemas/geoname.coffee'
import articleSchema from '/imports/schemas/article.coffee'
import Articles from '/imports/collections/articles.coffee'
import CuratorSources from '/imports/collections/curatorSources'
import Feeds from '/imports/collections/feeds'
import feedSchema from '/imports/schemas/feed'
import Constants from '/imports/constants.coffee'
import { regexEscape } from '/imports/utils'

DATA_VERSION = 13
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

oldUpdaters = ->
  Incidents.find(disease: $exists: false).forEach (incident) ->
    disease = UserEvents.findOne(incident.userEventId)?.disease
    if disease
      Incidents.update incident._id,
        $set: disease: disease

  # Set resolved diseases
  Incidents.find(
    resolvedDisease: {$exists: false}
    disease: {$exists: true}
  ).forEach (incident) ->
    if incident.disease
      console.log incident.disease
      requestResult = HTTP.get Constants.GRITS_URL + "/api/v1/disease_ontology/lookup",
        params:
          q: incident.disease
      result = requestResult.data.result
      if result.length > 0
        d = result[0]
        Incidents.update _id: incident._id,
          $set:
            resolvedDisease:
              id: d.uri
              text: d.label
      else
        Incidents.update _id: incident._id,
          $set:
            resolvedDisease:
              id: "userSpecifiedDisease:#{incident.disease}"
              text: "Other Disease: #{incident.disease}"

  promedFeed = Feeds.findOne(url: 'promedmail.org/post/')
  if not promedFeed?.title
    newFeedProps =
      title: 'ProMED-mail'
      url: 'promedmail.org/post/'
    feedSchema.validate(newFeedProps)
    Feeds.upsert promedFeed?._id,
      $set: newFeedProps
      $setOnInsert:
        addedDate: new Date()

  promedFeedId = Feeds.findOne(url: 'promedmail.org/post/')?._id

  Articles.find(
    url: $regex: /promedmail.org/
    feedId: $exists: false
  ).forEach (article) ->
    Articles.update article._id,
      $set: feedId: promedFeedId
      $unset: feed: ''

  CuratorSources.find().forEach (source) ->
    url = "promedmail.org/post/#{source._sourceId}"
    article =
      _id: source._id._str
      url: url
      addedDate: source.addedDate
      publishDate: source.publishDate
      publishDateTZ: "EDT"
      title: source.title
      reviewed: source.reviewed
      feedId: promedFeedId
    articleSchema.validate(article)
    Articles.upsert(article._id, article)

  Incidents.find(
    'articleId': {$exists: false}
    deleted: {$in: [null, false]}
  ).forEach (incident) ->
    incidentUrl = incident.url
    if _.isArray(incidentUrl)
      incidentUrl = incidentUrl[0]
    if not _.isString(incidentUrl)
      console.log "Invalid URL:", incidentUrl
      return
    article = Articles.findOne(url: {$regex: regexEscape(incidentUrl) + "$" })
    if article
      Incidents.update _id: incident._id,
        $set: articleId: article._id
        $unset: url: ''
    else
      console.log "No article with url:", incident.url

  # update articles to use arrays instead of strings for their UserEventId values
  Articles.find({userEventIds: $exists: false}).forEach (article) ->
    Articles.update _id: article._id,
      $set: userEventIds: [article.userEventId]

  Incidents.find(userEventId: $exists: true).forEach (incident) ->
    incidentData =
      id: incident._id
      associationDate: incident.creationDate or new Date
      associationUserId: incident.addedByUserId or ''
    UserEvents.update _id: incident.userEventId,
      $addToSet: incidents: incidentData
    Incidents.update _id: incident._id,
      $unset: userEventId: ''

  UserEvents.update {},
    $unset: articleCount: ''
    {multi: true}

  Articles.find().forEach (article) ->
    Articles.update _id: article._id,
      $unset: userEventId: ''

  console.log "Updating species field..."
  Incidents.find(species: $exists: true).forEach (incident) ->
    if incident.species?.id
      return
    else if /^human/i.test(incident.species)
      Incidents.update _id: incident._id,
        $set:
          species:
            id: "tsn:180092"
            text: "Homo sapiens"
    else if not incident.species
      Incidents.update _id: incident._id,
        $unset: species: ''
    else
      Incidents.update _id: incident._id,
        $set:
          species:
            id: "userSpecifiedSpecies:#{incident.species}"
            text: "Other Species: #{incident.species}"
      console.log('Unknown species: ' + incident.species)

  console.log "Updating geonames..."
  Incidents.find().map (incident) ->
    Incidents.update _id: incident._id,
      $set: locations: incident.locations.map (x)-> getGeonameById(x.id) or x
  console.log "done"

module.exports = ->
  if priorDataVersion and priorDataVersion >= DATA_VERSION
    return
  console.log "Running database update code..."

  if priorDataVersion < 8
    oldUpdaters()

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
  AppMetadata.upsert({property: "dataVersion"}, $set: {value: DATA_VERSION})

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

  console.log "database update complete"
