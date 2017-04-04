Template.curatorUserStatus.onCreated ->
  @userStatusHandle = @subscribe('userStatus')
  @otherActiveUser = new ReactiveVar null
  @autorun =>
    Meteor.call 'updateCuratorUserStatus', @data.selectedSourceId.get(), (err, res) =>
      if err
        toastr.error(err.message)

Template.curatorUserStatus.onRendered ->
  instance = @
  @autorun ->
    instance.otherActiveUser.get()
    instance.data.selectedSourceId.get()
    Meteor.defer ->
      $('.curator-viewing-status').tooltip
        container: 'body'
        placement: 'bottom'

Template.curatorUserStatus.onDestroyed ->
  Meteor.call 'updateCuratorUserStatus', null, (err, res) =>
    if err
      toastr.error(err.message)

Template.curatorUserStatus.helpers
  hasOnlineUsers: ->
    instance = Template.instance()
    # Find other users viewing the document selected by the current user
    otherUser = Meteor.users.findOne
      'status.online': true
      'status.curatorInboxSourceId': instance.data.selectedSourceId.get()
      _id: $ne: Meteor.userId()
    if otherUser
      instance.otherActiveUser.set(otherUser._id)
      true
