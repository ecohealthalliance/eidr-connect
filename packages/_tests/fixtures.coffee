if Meteor.isAppTest
  #import { exec } from 'child_process'
  exec = Npm.require('child_process').exec

  pwd = process.env.PWD
  mongo_path = "#{pwd}/node_modules/mongodb-prebuilt/binjs"
  mongo_host = '127.0.0.1'
  mongo_port = '27017'
  test_db = 'eidr-connect-test'

  syncExec = Meteor.wrapAsync(exec)

  Meteor.methods
    ###
    # load the database from a dump file
    #
    # @note this may periodically fail using mongodb-prebuilt JavaScript bridge,
    # using the operating system package manager for the mongorestore binary
    # has been the most stable option.
    # e.g. `apt-get install mongodb` or `brew install mongodb`
    # then setttings-dev.json under private
    #   mongo_path: '/usr/local/bin'
    # @see http://stackoverflow.com/questions/39719882/mongorestore-random-crash-fatal-error
    # @see https://github.com/golang/go/issues/17492
    # @see https://github.com/golang/go/issues/17490
    ###
    load: ->
      if mongo_path.includes('binjs')
        cmd = "#{mongo_path}/mongorestore.js --host #{mongo_host} --port #{mongo_port} -d #{test_db} #{pwd}/tests/dump/#{test_db}"
      else
        cmd = "#{mongo_path}/mongorestore --host #{mongo_host} --port #{mongo_port} -d #{test_db} #{pwd}/tests/dump/#{test_db}"
      try
        syncExec(cmd)
        Meteor.call('createTestingAdmin', cmd)
      catch error
        console.error(error.message)
        Meteor.call('reset', error, cmd)

    ###
    # reset - removes all data from the database
    ###
    reset: (error, cmd) ->
      allUsers = Meteor.users.find({}).fetch()
      for user in allUsers
        Roles.removeUsersFromRoles(user._id, 'admin')
      Package['xolvio:cleaner'].resetDatabase()
      users: allUsers
      context: @
      message: error
      cmd: cmd
      meteorSettings: Meteor.settings

    ###
    # createTestingAdmin - will create an admin account for testing
    ###
    createTestingAdmin: (cmd) ->
      email = 'chimp@testing1234.com'
      try
        newId = Accounts.createUser({
          email: email
          password: 'Pa55w0rd!'
          profile:
            name: 'Chimp'
        })
        Roles.addUsersToRoles(newId, ['admin'])
        id: newId
        cmd: cmd
        context: @
      catch error
        # this user shouldn't belong in the production database
        console.warn("TestingAdmin user '#{email}' exists")
        'Error! Context: ' + @
