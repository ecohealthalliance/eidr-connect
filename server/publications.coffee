Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
SmartEvents = require '/imports/collections/smartEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
Feeds = require '/imports/collections/feeds.coffee'
{ regexEscape, cleanUrl } = require '/imports/utils'

# Incidents
ReactiveTable.publish 'curatorEventIncidents', Incidents, {deleted: {$in: [null, false]}}
Meteor.publish 'eventIncidents', (incidentIds) ->
  Incidents.find
    _id: $in: incidentIds
    deleted: $in: [null, false]
Meteor.publish 'smartEventIncidents', (query) ->
  query.deleted = {$in: [null, false]}
  Incidents.find(query)
Meteor.publish 'mapIncidents', (userEventIds) ->
  Incidents.find({
    userEventId: $in: userEventIds
    locations: $ne: null
    deleted: $in: [null, false]
  }, {
    fields:
      userEventId: 1
      'dateRange.start': 1
      'dateRange.end': 1
      'dateRange.cumulative': 1
      locations: 1
      cases: 1
      deaths: 1
      specify: 1
  })

# User Events
ReactiveTable.publish('userEvents', UserEvents, {
  deleted: {$in: [null, false]}
}, {
  fields:
    articleCount: 1
    lastModifiedDate: 1
    eventName: 1
})
Meteor.publish 'userEvent', (eidID) ->
  UserEvents.find({_id: eidID})
Meteor.publish 'userEvents', ()->
  UserEvents.find({
    deleted: $in: [null, false]
  }, {
    field:
      eventName: 1
      lastIncidentDate: 1
  })

# Smart Events
ReactiveTable.publish 'smartEvents', SmartEvents, {deleted: {$in: [null, false]}}
Meteor.publish 'smartEvent', (eidID) ->
  SmartEvents.find({_id: eidID})
Meteor.publish 'smartEvents', () ->
  SmartEvents.find({deleted: {$in: [null, false]}})

Meteor.publish 'ArticleIncidentReports', (articleId) ->
  check(articleId, Match.Maybe(String))
  Incidents.find articleId: articleId,
    sort: 'annotations.case.0.textOffsets.0': 1

Meteor.publish 'eventArticles', (ueId) ->
  Articles.find(
    userEventIds: ueId
    deleted: {$in: [null, false]}
  )

Meteor.publish 'articles', (query={}) ->
  query.deleted = {$in: [null, false]}
  Articles.find(query)

Meteor.publish 'article', (sourceId) ->
  Articles.find(url: $regex: new RegExp("#{sourceId}$"))

Meteor.publish 'incidentArticle', (articleId) ->
  Articles.find(articleId)

Meteor.publish 'feeds', ->
  Feeds.find()

# User status
Meteor.publish 'userStatus', () ->
  Meteor.users.find({'status.online': true }, {fields: {'status': 1 }})
