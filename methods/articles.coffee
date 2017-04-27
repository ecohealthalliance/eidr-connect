Articles = require '/imports/collections/articles.coffee'
{ regexEscape } = require '/imports/utils'

Meteor.methods
  addEventSource: (source, eventId) -> #eventId, url, publishDate, publishDateTZ
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      # Check if Document is in collection
      sourceQuery = url: $regex: "#{regexEscape(source.url)}$"
      existingSource = Articles.findOne(sourceQuery)
      if existingSource
        #if this source is already in the DB and the userEvent isn't already associated - push it
        Articles.update sourceQuery,
          $addToSet: userEventIds: eventId
        Meteor.call("editUserEventArticleCount", eventId, 1)
        existingSource._id
      else
        if source.url
          insertArticle =
            url: source.url
            title: source.title
            userEventIds: [eventId]
          insertArticle = source
          insertArticle.addedByUserId = user._id
          insertArticle.addedByUserName = user.profile.name
          insertArticle.addedDate = new Date()
          newId = Articles.insert(insertArticle)
          Meteor.call("editUserEventLastModified", eventId)
          Meteor.call("editUserEventArticleCount", eventId, 1)
          return newId
    else
      throw new Meteor.Error("auth", "User does not have permission to add documents")

  updateEventSource: (source) ->
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      Articles.update source._id,
        $set:
          title: source.title
          publishDate: source.publishDate
          publishDateTZ: source.publishDateTZ
      Meteor.call("editUserEventLastModified", source.userEventId)
    else
      throw new Meteor.Error("auth", "User does not have permission to edit documents")

  removeEventSource: (id, userEventId) ->
    if Roles.userIsInRole(Meteor.userId(), ['admin'])
      removed = Articles.findOne(id)
      removed.userEventIds = _.filter removed.userEventIds, (currentUserEventId) ->
        currentUserEventId != userEventId
      Articles.update id,
        $set:
          userEventIds: removed.userEventIds
      Meteor.call("editUserEventLastModified", userEventId)
      Meteor.call("editUserEventArticleCount", userEventId, -1)

  markSourceReviewed: (id, reviewed) ->
    if Roles.userIsInRole(Meteor.userId(), ['curator', 'admin'])
      Articles.update _id: id,
        $set:
          reviewed: reviewed
