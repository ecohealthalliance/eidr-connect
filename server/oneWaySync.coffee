import UserEvents from '/imports/collections/userEvents.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import Articles from '/imports/collections/articles.coffee'

module.exports = (url)->
  url = process.env.ONE_WAY_SYNC_URL + "/api/events-incidents-articles"
  console.log("syncing from: " + url)
  skip = 0
  limit = 10
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
      incidents = doc._incidents
      articles = doc._articles
      delete doc._incidents
      delete doc._articles
      if not UserEvents.findOne(doc._id)?.deleted
        UserEvents.upsert(doc._id, doc)
      for incident in incidents
        if not Incidents.findOne(incident._id)?.deleted
          Incidents.upsert(incident._id, incidents)
      for article in articles
        if not Articles.findOne(article._id)?.deleted
          Articles.upsert(article._id, article)
  console.log("done")

