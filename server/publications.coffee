Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
SmartEvents = require '/imports/collections/smartEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
Feeds = require '/imports/collections/feeds.coffee'
{ regexEscape, cleanUrl } = require '/imports/utils'

# Incidents
ReactiveTable.publish 'curatorEventIncidents', Incidents,
  deleted: {$in: [null, false]}

Meteor.publish 'smartEventIncidents', (query) ->
  query = _.extend query,
    accepted: $in: [null, true]
    deleted: $in: [null, false]
  Incidents.find(query)

Meteor.publish 'mapIncidents', (incidentIds) ->
  Incidents.find
    _id: $in: incidentIds
    locations: $ne: null
    deleted: $in: [null, false]
    {
      fields:
        userEventId: 1
        'dateRange.start': 1
        'dateRange.end': 1
        'dateRange.cumulative': 1
        locations: 1
        cases: 1
        deaths: 1
        specify: 1
    }

Meteor.publish 'articleIncidents', (articleId) ->
  check(articleId, Match.Maybe(String))
  query =
    articleId: articleId
    deleted: $in: [null, false]
  Incidents.find query,
    sort: 'annotations.case.0.textOffsets.0': 1

# User Events
ReactiveTable.publish 'userEvents', UserEvents,
  {deleted: $in: [null, false]},
  fields:
    lastModifiedDate: 1
    eventName: 1
    incidents: 1

Meteor.publish 'userEvents', () ->
  UserEvents.find deleted: $in: [null, false],
    field:
      eventName: 1
      lastIncidentDate: 1

Meteor.publishComposite 'userEvent', (eventId) ->
  find: ->
    UserEvents.find(_id: eventId)
  children: [
    {
    collectionName: 'eventIncidents'
    find: (event) ->
      incidentIds = _.pluck(event.incidents, 'id')
      Incidents.find
        _id: $in: incidentIds
        deleted: $in: [null, false]
    }
    {
    collectionName: 'eventArticles'
    find: (event) ->
      incidents = Incidents.find(_id: $in: _.pluck(event.incidents, 'id'))
      Articles.find
        $or: [
          {_id: $in: _.pluck(incidents.fetch(), 'articleId')}
          {userEventIds: event._id}
        ]
        deleted: {$in: [null, false]}
    }
  ]

# Smart Events
ReactiveTable.publish 'smartEvents', SmartEvents, deleted: $in: [null, false]

Meteor.publish 'smartEvent', (eidID) ->
  SmartEvents.find({_id: eidID})

Meteor.publish 'smartEvents', () ->
  SmartEvents.find({deleted: {$in: [null, false]}})

# Articles
Meteor.publish 'articles', (query={}) ->
  query.deleted = {$in: [null, false]}
  Articles.find(query)

Meteor.publish 'article', (sourceId) ->
  Articles.find(url: $regex: new RegExp("#{sourceId}$"))

Meteor.publish 'incidentArticle', (articleId) ->
  Articles.find(articleId)

# Feeds
Meteor.publish 'feeds', ->
  Feeds.find()

# User status
Meteor.publish 'userStatus', () ->
  Meteor.users.find({'status.online': true }, {fields: {'status': 1 }})
