import Incidents from '/imports/collections/incidentReports.coffee'
import UserEvents from '/imports/collections/userEvents.coffee'
import SmartEvents from '/imports/collections/smartEvents.coffee'
import AutoEvents from '/imports/collections/autoEvents.coffee'
import Articles from '/imports/collections/articles.coffee'
import Feeds from '/imports/collections/feeds.coffee'
import regionToCountries from '/imports/regionToCountries.json'

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
  Incidents.find
    articleId: articleId
    deleted: $in: [null, false]
    {sort: 'annotations.case.0.textOffsets.0': 1}

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
      collectionName: 'users'
      find: (event) ->
        Meteor.users.find({
          _id: $in: [event.createdByUserId, event.lastModifiedByUserId]
        }, {
          fields:
            'profile.name': 1
        })
    }, {
      collectionName: 'eventIncidents'
      find: (event) ->
        incidentIds = _.pluck(event.incidents, 'id')
        Incidents.find
          _id: $in: incidentIds
          deleted: $in: [null, false]
    }, {
      collectionName: 'articles'
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

eventToIncidentQuery = (event) ->
  query =
    accepted: $in: [null, true]
    deleted: $in: [null, false]
    locations: $not: $size: 0
  if event.diseases and event.diseases.length > 0
    query['resolvedDisease.id'] = $in: event.diseases.map (x) -> x.id
  eventDateRange = event.dateRange
  if eventDateRange
    if eventDateRange.end
      query['dateRange.start'] = $lte: eventDateRange.end
    if eventDateRange.start
      query['dateRange.end'] = $gte: eventDateRange.start
  locationQueries = []
  for location in (event.locations or [])
    locationQueries.push
      id: location.id
    if location.id of regionToCountries
      locationQueries.push
        countryCode: $in: regionToCountries[location.id].countryISOs
      continue
    locationQuery =
      countryName: location.countryName
    featureCode = location.featureCode
    if featureCode.startsWith("PCL")
      locationQueries.push(locationQuery)
    else
      locationQuery.admin1Name = location.admin1Name
      if featureCode is 'ADM1'
        locationQueries.push(locationQuery)
      else
        locationQuery.admin2Name = location.admin2Name
        if featureCode is 'ADM2'
          locationQueries.push(locationQuery)
  locationQueries = locationQueries.map (locationQuery) ->
    result = {}
    for prop, value of locationQuery
      result["locations.#{prop}"] = value
    return result
  if locationQueries.length > 0
    query['$or'] = locationQueries
  query

Meteor.publishComposite 'smartEvent', (eventId) ->
  find: ->
    SmartEvents.find(_id: eventId)
  children: [
    {
      collectionName: 'users'
      find: (event) ->
        Meteor.users.find({
          _id: $in: [event.createdByUserId, event.lastModifiedByUserId]
        }, {
          fields:
            'profile.name': 1
        })
    }, {
      collectionName: 'eventIncidents'
      find: (event) ->
        Incidents.find(eventToIncidentQuery(event))
    }
  ]

Meteor.publishComposite 'autoEvent', (eventId) ->
  find: ->
    AutoEvents.find(_id: eventId)
  children: [
    {
      collectionName: 'eventIncidents'
      find: (event) ->
        Incidents.find(eventToIncidentQuery(event))
    }
  ]

ReactiveTable.publish 'smartEvents', SmartEvents, deleted: $in: [null, false]

ReactiveTable.publish 'autoEvents', AutoEvents

Meteor.publish 'articles', (query={}) ->
  if not Roles.userIsInRole(@userId, ['admin', 'curator'])
    throw new Meteor.Error('auth', 'User does not have permission to access articles')
  query.deleted = {$in: [null, false]}
  Articles.find(query, {
    fields:
      'enhancements.source.scrapedData': 0
  })

Meteor.publish 'article', (sourceId) ->
  Articles.find(url: $regex: new RegExp("#{sourceId}$"))

Meteor.publish 'incidentArticle', (articleId) ->
  Articles.find(articleId)

Meteor.publish 'feeds', ->
  Feeds.find()

Meteor.publish "allUsers", ->
  if not Roles.userIsInRole(@userId, ['admin'])
    throw new Meteor.Error('auth', 'User does not have permission to access user data')
  Meteor.users.find({}, {fields: {'_id': 1, 'roles': 1, 'profile.name': 1, 'emails': 1}})

Meteor.publish "user", ->
  Meteor.users.find(_id: @userId)

Meteor.publish "roles", () ->
  Meteor.roles.find({})

Meteor.publish 'userStatus', () ->
  Meteor.users.find({'status.online': true }, {fields: {'status': 1 }})
