Template.adminUser.helpers
  isCurrentUser: ->
    this._id == Meteor.userId()

  isAdmin: ->
    Roles.userIsInRole(this._id, ["admin"])

  name: ->
    this.profile.name

  email: ->
    if this.services.google
      return this.services.google.email
    return this.emails[0].address

Template.adminUser.events
  'click .make-admin': (event) ->
    userId = event.target.getAttribute('user-id')
    Meteor.call('makeAdmin', userId)

  'click .remove-admin': (event) ->
    userId = event.target.getAttribute('user-id')
    Meteor.call('removeAdmin', userId)

Template.createAccount.events
  'submit #add-account': (event) ->
    event.preventDefault()

    name = event.target.name.value.trim()
    email = event.target.email.value.trim()
    makeAdmin = event.target.admin.checked

    if name.length and email.length
      Meteor.call('createAccount', email, name, makeAdmin, (error, result) ->
        if error
          if error.error is 'allUsers.createAccount.exists'
            toastr.error("The specified email address is already being used.")
          else
            toastr.error(error.error)
        else
          Router.go('admins')
          toastr.success("Account created for "+ email)	
      )
    else
      toastr.error("Enter an email address and name.")
