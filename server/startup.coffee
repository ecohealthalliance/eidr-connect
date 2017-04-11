UserEvents = require '/imports/collections/userEvents.coffee'
incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
articleSchema = require '/imports/schemas/article.coffee'
Articles = require '/imports/collections/articles.coffee'
PromedPosts = require '/imports/collections/promedPosts.coffee'
CuratorSources = require '/imports/collections/curatorSources'
Feeds = require '/imports/collections/feeds'
feedSchema = require '/imports/schemas/feed'
Constants = require '/imports/constants.coffee'

Meteor.startup ->
  # set incident dates
  incidents = Incidents.find({deleted: {$in: [null, false]}}).fetch()
  for incident in incidents
    try
      incidentReportSchema.validate(incident)
    catch error
      console.log error
      console.log JSON.stringify(incident, 0, 2)

  # Clean-up curatorInboxSourceId when user goes offline
  Meteor.users.find({'status.online': true}).observe
    removed: (user) ->
      Meteor.users.update(user._id, {$set : {'status.curatorInboxSourceId': null}})

  # If a remote EIDR-C instance url is provided, periodically pull data from it.
  if process.env.ONE_WAY_SYNC_URL
    syncCollection = (collection, url)->
      console.log("syncing from: " + url)
      skip = 0
      limit = 100
      loop
        resp = HTTP.get(url,
          params:
            skip: skip
            limit: limit
        )
        docs = EJSON.parse(resp.content)
        skip += limit
        if docs.length == 0 then break
        for doc in docs
          if not collection.findOne(doc._id)?.deleted
            collection.upsert(doc._id, doc)
      console.log("done")
    pullRemoteInstanceData = ->
      syncCollection(UserEvents, process.env.ONE_WAY_SYNC_URL + "/api/events")
      syncCollection(Incidents, process.env.ONE_WAY_SYNC_URL + "/api/incidents")
      syncCollection(Articles, process.env.ONE_WAY_SYNC_URL + "/api/articles")

    # Do initial sync on startup
    Meteor.setTimeout(pullRemoteInstanceData, 1000)
    # Pull data every 6 hours
    Meteor.setInterval(pullRemoteInstanceData, 6 * 60 * 60 * 1000)

  Incidents.find(disease: $exists: false).forEach (incident) ->
    disease = UserEvents.findOne(incident.userEventId)?.disease
    if disease
      Incidents.update incident._id,
        $set: disease: disease

  # Soft delete incidents of deleted user events
  UserEvents.find({deleted: true}, {fields: _id:1}).forEach (event) ->
    Incidents.update {userEventId: event._id, deleted: {$in: [null, false]}},
      $set:
        deleted: true
        deletedDate: new Date()

  # Store urls on incidents as strings rather than arrays
  Incidents.find('url.0': {$exists: true}).forEach (incident) ->
    Incidents.update _id: incident._id,
      $set: url: incident.url[0]

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

  promedFeedId = Feeds.findOne(title: 'ProMED-mail')?._id

  if not promedFeedId
    promedFeed =
      title: 'ProMED-mail'
      url: 'promedmail.org/post/'
      addedDate: new Date()
    feedSchema.validate(promedFeed)
    promedFeedId = Feeds.insert(promedFeed)

  Articles.find(
    url: $regex: /promedmail.org/
    feed: $exists: false
  ).forEach (article) ->
    Articles.update article._id,
      $set: feedId: promedFeedId

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
