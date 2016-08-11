'use strict'

Meteor.methods
  reset: ->
    allUsers = Meteor.users.find({}).fetch()
    for user in allUsers
      Roles.removeUsersFromRoles(user._id, 'admin')
    Package['xolvio:cleaner'].resetDatabase()

  createTestingAdmin: ->
    newId = Accounts.createUser({
      email: "chimp@testing1234.com",
      password: "Pa55w0rd!",
      profile: {
        name: "Chimp"
      }
    })
    Roles.addUsersToRoles(newId, ['admin'])
