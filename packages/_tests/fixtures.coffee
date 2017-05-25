if Meteor.isAppTest
  #import { exec } from 'child_process'
  exec = Npm.require('child_process').exec

  pwd = process.env.PWD
  mongo_path = Meteor.settings.private?.mongo_path || "#{pwd}/node_modules/mongodb-prebuilt/binjs"
  mongo_host = Meteor.settings.private?.mongo_host || '127.0.0.1'
  mongo_port = Meteor.settings.private?.mongo_port || '27017'
  test_db = Meteor.settings.private?.test_db || 'eidr-connect-test'

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
      try
        # Loading test data into database
        Meteor.call 'createTestingAdmin'
        console.log "created admin"
        userEvent = Meteor.call 'upsertUserEvent',
                    eventName: 'Test Event 1',
                    summary: 'Test summary'
        article = Meteor.call 'addEventSource',
                    title: 'Test Article',
                    url: 'http://promedmail.org/post/418162'
                    publishDate: new Date()
                    publishDateTZ: 'EST',
                    userEvent.insertedId,
                    (error, article) ->
                      console.log "article", error, article
        incident = Meteor.call 'addIncidentReport',
                    species: 'Test Species',
                    cases: 1,
                    dateRange: {}

      catch error
        console.log "error loading data", error
        Meteor.call('reset')


    ###
    # reset - removes all data from the database
    ###
    reset: ->
      allUsers = Meteor.users.find({}).fetch()
      for user in allUsers
        Roles.removeUsersFromRoles(user._id, 'admin')
      Package['xolvio:cleaner'].resetDatabase()

    ###
    # createTestingAdmin - will create an admin account for testing
    ###
    createTestingAdmin: ->
      email = 'chimp@testing1234.com'
      try
        newId = Accounts.createUser({
          email: email
          password: 'Pa55w0rd!'
          profile:
            name: 'Chimp'
        })
        @setUserId newId
        Roles.addUsersToRoles(newId, ['admin'])
      catch error
        # this user shouldn't belong in the production database
        console.warn("TestingAdmin user '#{email}' exists")
