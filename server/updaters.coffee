# Code for updating the database on startup
UserEvents = require '/imports/collections/userEvents.coffee'
incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
articleSchema = require '/imports/schemas/article.coffee'
Articles = require '/imports/collections/articles.coffee'
CuratorSources = require '/imports/collections/curatorSources'
Feeds = require '/imports/collections/feeds'
feedSchema = require '/imports/schemas/feed'
Constants = require '/imports/constants.coffee'
{ regexEscape } = require '/imports/utils'

DATA_VERSION = 2
AppMetadata = new Meteor.Collection('appMetadata')
priorDataVersion = AppMetadata.findOne(property: "dataVersion")?.value

Meteor.startup ->
  if priorDataVersion and priorDataVersion >= DATA_VERSION
    return
  console.log "Running database update code..."
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

  AppMetadata.upsert({property: "dataVersion"}, $set: {value: DATA_VERSION})
  console.log "database update complete"
