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
    userEvents = EJSON.parse(resp.content)
    skip += limit
    if userEvents.length == 0 then break
    for userEvent in userEvents
      priorEvent = UserEvents.findOne(userEvent._id)
      if priorEvent?.deleted
        continue
      incidents = userEvent._incidents
      articles = userEvent._articles
      delete userEvent._incidents
      delete userEvent._articles
      newIncidents = []
      for incident in incidents
        priorIncident = Incidents.findOne(incident._id)
        if not priorIncident
          newIncidents.push
            id: incident._id
            associationDate: new Date()
        if not priorIncident?.deleted
          Incidents.upsert(incident._id, incident)
      for article in articles
        priorArticle = Articles.findOne(article._id)
        if not priorArticle
          Articles.upsert(article._id, article)
      if priorEvent
        # Check if the the event has changed.
        if not(userEvent.deleted or newIncidents.length > 0)
          return
        # Only add the incidents that weren't in the incidents collection before.
        # The others may have been intentionally removed from the event on this instance.
        UserEvents.update(userEvent._id,
          # Changes to properties like name/summary/disease are ignored so
          # local edits are preserved
          $set:
            incidents: (priorEvent?.incidents or []).concat(newIncidents)
            lastModifiedDate: new Date()
            deleted: userEvent.deleted
            lastModifiedByUserName: "Sync from " + process.env.ONE_WAY_SYNC_URL
            lastModifiedByUserId: "sync:" + process.env.ONE_WAY_SYNC_URL
        )
        Meteor.call('editUserEventLastIncidentDate', userEvent._id)
      else
        UserEvents.upsert(userEvent._id, userEvent)
  console.log("sync complete")
