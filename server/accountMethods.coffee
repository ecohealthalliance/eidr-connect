Meteor.methods
  makeAdmin: (userId) ->
    currentUserId = Meteor.userId()
    if Roles.userIsInRole(currentUserId, ['admin'])
      Roles.addUsersToRoles(userId, ['admin'])
    else
      throw new Meteor.Error(403, "Not authorized")

  removeAdmin: (userId) ->
    currentUserId = Meteor.userId()
    if Roles.userIsInRole(currentUserId, ['admin'])
      Roles.removeUsersFromRoles(userId, 'admin')
    else
      throw new Meteor.Error(403, "Not authorized")

  makeCurator: (userId) ->
    currentUserId = Meteor.userId()
    if Roles.userIsInRole(currentUserId, ['admin'])
      Roles.addUsersToRoles(userId, ['curator'])
    else
      throw new Meteor.Error(403, "Not authorized")

  removeCurator: (userId) ->
    currentUserId = Meteor.userId()
    if Roles.userIsInRole(currentUserId, ['admin'])
      Roles.removeUsersFromRoles(userId, 'curator')
    else
      throw new Meteor.Error(403, "Not authorized")

  createAccount: (email, profileName, giveAdminRole) ->
    if Roles.userIsInRole(Meteor.userId(), ['admin'])
      existingUser = Accounts.findUserByEmail(email)
      if existingUser
        throw new Meteor.Error('allUsers.createAccount.exists')
      else
        newUserId = Accounts.createUser({
          email: email,
          profile: {
            name: profileName
          }
        })

        if giveAdminRole
          Roles.addUsersToRoles(newUserId, ['admin'])
        Accounts.sendEnrollmentEmail(newUserId)
    else
      throw new Meteor.Error(403, "Not authorized")
