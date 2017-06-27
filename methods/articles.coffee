import Articles from '/imports/collections/articles.coffee'
import ArticleSchema from '/imports/schemas/article'
import Incidents from '/imports/collections/incidentReports.coffee'
import UserEvents from '/imports/collections/userEvents.coffee'
import { regexEscape } from '/imports/utils'

Meteor.methods
  addEventSource: (source, eventId) ->
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      # Check if Document is in collection
      if source.url
        sourceQuery = url: $regex: "#{regexEscape(source.url)}$"
        existingSource = Articles.findOne(sourceQuery)

      if existingSource
        # If this source is already in the DB and the userEvent isn't already
        # associated - push it
        Articles.update sourceQuery,
          $addToSet: userEventIds: eventId
        existingSource._id
      else
        source.userEventIds = [eventId]
        source.addedByUserId = user._id
        source.addedByUserName = user.profile.name
        source.addedDate = new Date()
        ArticleSchema.validate(source)
        newId = Articles.insert(source)
        Meteor.call("editUserEventLastModified", eventId)
        return newId
    else
      throw new Meteor.Error('auth',
        'User does not have permission to add documents')

  associateWithEvent: (sourceId, eventId) ->
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      Articles.update sourceId,
        $addToSet: userEventIds: eventId
    else
      throw new Meteor.Error('auth',
        'User does not have permission to edit documents')

  updateEventSource: (source) ->
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      Articles.update source._id,
        $set:
          title: source.title
          publishDate: source.publishDate
          publishDateTZ: source.publishDateTZ
      Meteor.call('editUserEventLastModified', source.userEventId)
    else
      throw new Meteor.Error('auth',
        'User does not have permission to edit documents')

  removeEventSource: (id, userEventId) ->
    if Meteor.isServer
      if Roles.userIsInRole(Meteor.userId(), ['admin'])
        removed = Articles.findOne(id)
        removed.userEventIds = _.filter removed.userEventIds, (currentUserEventId) ->
          currentUserEventId != userEventId
        Articles.update id,
          $set:
            userEventIds: removed.userEventIds
        Meteor.call("editUserEventLastModified", userEventId)

  removeDocument: (id) ->
    documentToRemove = Articles.findOne(id)
    if (Roles.userIsInRole(Meteor.userId(), ['admin']) or
      documentToRemove.addedByUserId == @userId
    )
      incidentIds = Incidents.find(articleId: id).map((x)-> x._id)
      userEventIds = UserEvents.find(
        'incidents.id': $in: incidentIds
      ).map((x)-> x._id)
      UserEvents.update({
        'incidents.id': $in: incidentIds
      }, {
        $pull:
          incidents:
            id:
              $in: incidentIds
      }, {
        multi: true
      })
      Incidents.remove(articleId: id)
      Articles.remove(id)
      userEventIds.map (userEventId)->
        Meteor.call('editUserEventLastModified', userEventId)
        Meteor.call('editUserEventLastIncidentDate', userEventId)
    else
      throw new Meteor.Error('auth', 'User does not have permission delete this document')

  markSourceReviewed: (id, reviewed) ->
    if Roles.userIsInRole(Meteor.userId(), ['curator', 'admin'])
      Articles.update _id: id,
        $set:
          reviewed: reviewed
