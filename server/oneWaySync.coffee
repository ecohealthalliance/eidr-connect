serEvents = require '/imports/collections/userEvents.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
Articles = require '/imports/collections/articles.coffee'

Meteor.startup ->
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
