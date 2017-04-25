Articles = require '/imports/collections/articles.coffee'
{ regexEscape } = require '/imports/utils'

Meteor.methods
  addEventSource: (source) -> #eventId, url, publishDate, publishDateTZ
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      # Check if Document is in collection
      sourceQuery = url: $regex: "#{regexEscape(source.url)}$"
      existingSource = Articles.findOne(sourceQuery)
      console.log "existing source:", existingSource
      if existingSource
        #if this source is already in the DB and the userEvent isn't already associated - push it
        if !existingSource.userEventIds or existingSource.userEventIds.indexOf(source.userEventId) == -1
          Articles.update sourceQuery,
            $push: userEventIds: source.userEventId
        existingSource._id
      else
        if source.url
          insertArticle =
            url: source.url
            title: source.title
            userEventIds: [source.userEventId]
          insertArticle = source
          insertArticle.addedByUserId = user._id
          insertArticle.addedByUserName = user.profile.name
          insertArticle.addedDate = new Date()
          newId = Articles.insert(insertArticle)
          Meteor.call("editUserEventLastModified", insertArticle.userEventId)
          Meteor.call("editUserEventArticleCount", insertArticle.userEventId, 1)
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
      console.log "removed", id, removed
      removed.userEventIds = _.filter removed.userEventIds, (currentUserEventId) ->
        currentUserEventId != userEventId
      # if there is nothing in the userEventIds array after we delete the userEventId in question then mark the article as deleted
      if !removed.userEventIds.length
        Articles.update id,
          $set:
            deleted: true,
            deletedDate: new Date()
      else # otherwise just remove the userEventId in question from the array
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
