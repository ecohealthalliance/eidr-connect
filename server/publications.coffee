Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
SmartEvents = require '/imports/collections/smartEvents.coffee'
CuratorSources = require '/imports/collections/curatorSources.coffee'
Articles = require '/imports/collections/articles.coffee'
Feeds = require '/imports/collections/feeds.coffee'

# Incidents
ReactiveTable.publish 'curatorEventIncidents', Incidents, {deleted: {$in: [null, false]}}
Meteor.publish 'eventIncidents', (userEventId) ->
  Incidents.find({userEventId: userEventId, deleted: {$in: [null, false]}})
Meteor.publish 'mapIncidents', () ->
  Incidents.find({
    locations: {$ne: null},
    deleted: {$in: [null, false]}
  },
  {fields:
      userEventId: 1
      'dateRange.start': 1
      'dateRange.end': 1
      'dateRange.cumulative': 1
      locations: 1
      cases: 1
  })

# User Events
ReactiveTable.publish 'userEvents', UserEvents, {deleted: {$in: [null, false]}}
Meteor.publish 'userEvent', (eidID) ->
  UserEvents.find({_id: eidID})
Meteor.publish 'userEvents', () ->
  UserEvents.find({deleted: {$in: [null, false]}})

# Smart Events
ReactiveTable.publish 'smartEvents', SmartEvents, {deleted: {$in: [null, false]}}
Meteor.publish 'smartEvent', (eidID) ->
  SmartEvents.find({_id: eidID})
Meteor.publish 'smartEvents', () ->
  SmartEvents.find({deleted: {$in: [null, false]}})

# Curator Sources
ReactiveTable.publish 'curatorSources', CuratorSources, {}
Meteor.publish 'curatorSources', (query) ->
  CuratorSources.find(query, {
    sort:
      publishDate: -1
  })

Meteor.publish 'eventArticles', (ueId) ->
  Articles.find(
    userEventId: ueId
    deleted: {$in: [null, false]}
  )

Meteor.publish 'articles', (query={}) ->
  query.deleted = {$in: [null, false]}
  Articles.find(query)

Meteor.publish 'feeds', ->
  Feeds.find()

# User status
Meteor.publish 'userStatus', () ->
  Meteor.users.find({'status.online': true }, {fields: {'status': 1 }})
