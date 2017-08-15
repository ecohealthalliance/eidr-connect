if Meteor.isAppTest
  #import { exec } from 'child_process'
  exec = Npm.require('child_process').exec

  pwd = process.env.PWD
  mongo_path = Meteor.settings.private?.mongo_path || "#{pwd}/node_modules/mongodb-prebuilt/binjs"
  mongo_host = Meteor.settings.private?.mongo_host || '127.0.0.1'
  mongo_port = Meteor.settings.private?.mongo_port || '27017'
  test_db = Meteor.settings.private?.test_db || 'eidr-connect-test'

  syncExec = Meteor.wrapAsync(exec)

  locations1 = [
    id: '5165418'
    name: 'Ohio'
    admin1Name: 'Ohio'
    admin2Name: null
    latitude: 40.25034
    longitude: -83.00018
    countryName: 'United States'
    countryCode: 'US'
    population: 11467123
    featureClass: 'A'
    featureCode: 'ADM1'
    alternateNames: [
      '\'Ohaio'
      'Buckeye State'
    ]
  ]

  locations2 = [
    id: '2419472'
    name: 'Kissidougou'
    admin1Name: 'Faranah Region'
    admin2Name: 'Kissidougou'
    latitude: 9.1848
    longitude: -10.09987
    countryName: 'Republic of Guinea'
    countryCode: 'GN'
    population: 47099
    featureClass: 'P'
    featureCode: 'PPLA2'
    alternateNames: [
      'KSI'
    ]
  ]

  testEvent =
    eventName: 'Test Event 1'
    summary: 'Test summary'

  testSource =
    title: 'Test Article',
    url: 'http://promedmail.org/post/418162'
    publishDate: new Date()
    publishDateTZ: 'EST'

  testSource2 =
    title: 'Test Article 2',
    url: 'http://promedmail.org/post/5220233'
    publishDate: new Date()
    publishDateTZ: 'EST'

  testIncident =
    species:
      id: "tsn:180092"
      text: "Homo sapiens"
    cases: 375
    locations: locations1
    dateRange:
      cumulative: false
      type: 'day'

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
        { insertedId } = Meteor.call('upsertUserEvent', testEvent)
        eventId = insertedId
        console.log 'UserEvent created', eventId
        testSource.userEventIds = [eventId]
        articleId = Meteor.call('addEventSource', testSource, eventId)
        console.log 'Article created', articleId
        testIncident.dateRange.start = new Date()
        testIncident.dateRange.end = new Date()
        testIncident.articleId = articleId
        incidentId = Meteor.call('addIncidentReport', testIncident)
        console.log 'Incident created', incidentId
        Meteor.call 'addIncidentToEvent', eventId, incidentId

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

    addIncidents: (eventId, incidentCount) ->
      articleId = Meteor.call('addEventSource', testSource2, eventId)
      for num in [1...incidentCount + 1]
        incident = Object.assign({}, testIncident)
        date = new Date()
        if num > 1
          date.setDate(date.getDate() - 14 * num)
          incident.cases = num * 100
        else
          delete incident.cases
          incident.deaths = 200
          incident.travelRelated = true
          incident.locations = locations2
        if num > 2
          incident.status = 'confirmed'
        incident.dateRange.start = date
        incident.dateRange.end = date
        incident.articleId = articleId
        console.log incident
        incidentId = Meteor.call('addIncidentReport', incident)
        console.log incidentId
        Meteor.call('addIncidentToEvent', eventId, incidentId)
