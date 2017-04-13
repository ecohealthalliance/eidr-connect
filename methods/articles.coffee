Articles = require '/imports/collections/articles.coffee'
{ regexEscape } = require '/imports/utils'

Meteor.methods
  addEventSource: (source) -> #eventId, url, publishDate, publishDateTZ
    user = Meteor.user()
    if user and Roles.userIsInRole(user._id, ['admin'])
      # Check if Document is in collection
      if source.url
        sourceQuery = url: $regex: "#{regexEscape(source.url)}$"
        existingSource = Articles.findOne(sourceQuery)
      if existingSource
        Articles.update sourceQuery,
          $set: userEventId: source.userEventId
      else
        insertArticle =
          url: source.url
          title: source.title
          userEventId: source.userEventId
        insertArticle = source
        insertArticle.addedByUserId = user._id
        insertArticle.addedByUserName = user.profile.name
        insertArticle.addedDate = new Date()
        newId = Articles.insert(insertArticle)
        if insertArticle.userEventId
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

  removeEventSource: (id) ->
    if Roles.userIsInRole(Meteor.userId(), ['admin'])
      removed = Articles.findOne(id)
      Articles.update id,
        $set:
          deleted: true,
          deletedDate: new Date()
      Meteor.call("editUserEventLastModified", removed.userEventId)
      Meteor.call("editUserEventArticleCount", removed.userEventId, -1)

  markSourceReviewed: (id, reviewed) ->
    if Roles.userIsInRole(Meteor.userId(), ['curator', 'admin'])
      Articles.update _id: id,
        $set:
          reviewed: reviewed
