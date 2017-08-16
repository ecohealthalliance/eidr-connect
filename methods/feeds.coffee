Feeds = require '/imports/collections/feeds'
{ regexEscape } = require '/imports/utils'

Meteor.methods
  addFeed: (feed) ->
    url = feed.url
    user = Meteor.user()
    urlWithoutProtocol = url.replace(/^https?\:\/\//i, '');
    regex = new RegExp "^https?:\/\/#{regexEscape(urlWithoutProtocol)}"
    if Feeds.findOne(url: {$regex: regex})
      if Meteor.isServer
        throw new Meteor.Error('duplicate_entry', "#{url} has already been added.")
      return

    if not Roles.userIsInRole(user._id, ['admin'])
      if Meteor.isServer
        throw new Meteor.Error('auth', 'User does not have permission to create incidents')
      return

    feed.addedByUserId = user._id
    feed.addedDate = new Date()
    Feeds.insert feed

  removeFeed: (feedId) ->
    if not Roles.userIsInRole(Meteor.user()._id, ['admin'])
      if Meteor.isServer
        throw new Meteor.Error('auth', 'User does not have permission to delete incidents')
      return
    if Feeds.findOne(feedId)?.default
      throw new Meteor.Error('', 'Cannot delete the default feed')
      return
    Feeds.remove feedId
