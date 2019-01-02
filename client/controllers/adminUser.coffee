Template.adminUser.helpers
  isCurrentUser: ->
    this._id == Meteor.userId()

  isCurator: ->
    Roles.userIsInRole(this._id, ["curator"])

  isAdmin: ->
    Roles.userIsInRole(this._id, ["admin"])

  name: ->
    this.profile.name

  email: ->
    return this.emails?[0].address

Template.adminUser.events
  'click .make-curator': (event, template) ->
    Meteor.call('makeCurator', template.data._id)

  'click .remove-curator': (event, template) ->
    Meteor.call('removeCurator', template.data._id)

  'click .make-admin': (event, template) ->
    Meteor.call('makeAdmin', template.data._id)

  'click .remove-admin': (event, template) ->
    Meteor.call('removeAdmin', template.data._id)
