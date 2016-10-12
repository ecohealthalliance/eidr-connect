Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
CuratorSources = require '/imports/collections/curatorSources.coffee'
Articles = require '/imports/collections/articles.coffee'

# Incidents
ReactiveTable.publish "curatorEventIncidents", Incidents
Meteor.publish "eventIncidents", (userEventId) ->
  Incidents.find({userEventId: userEventId})
Meteor.publish "mapIncidents", () ->
  Incidents.find({locations: {$ne: null}}, {
    fields:
      userEventId: 1
      "dateRange.start": 1
      "dateRange.end": 1
      "dateRange.cumulative": 1
      locations: 1
  })

# User Events
ReactiveTable.publish "userEvents", UserEvents, {}
Meteor.publish "userEvent", (eidID) ->
  UserEvents.find({_id: eidID})
Meteor.publish "userEvents", () ->
  UserEvents.find()

# Curator Sources
ReactiveTable.publish "curatorSources", CuratorSources, {}
Meteor.publish "curatorSources", (range) ->
  endDate = new Date()
  if range?.endDate
    endDate = range.endDate
  startDate = moment(endDate).subtract(2, 'weeks').toDate()
  if range?.startDate
    startDate = range.startDate
  query =
    publishDate:
      $gte: new Date(startDate)
      $lte: new Date(endDate)
  CuratorSources.find(query, {
    sort:
      publishDate: -1
  })

Meteor.publish "eventArticles", (ueId) ->
  Articles.find({userEventId: ueId})
