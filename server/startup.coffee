import incidentReportSchema from '/imports/schemas/incidentReport'
import Incidents from '/imports/collections/incidentReports'
import Articles from '/imports/collections/articles'
import autoprocessArticles from '/server/autoprocess'
import updateDatabase from '/server/updaters'
import syncCollection from '/server/oneWaySync'
import syncStructuredFeeds from '/server/syncStructuredFeeds'
import updateAutoEvents from '/server/updateAutoEvents'
import Feeds from '/imports/collections/feeds'
import feedSchema from '/imports/schemas/feed'

Meteor.startup ->
  # Clean-up curatorInboxSourceId when user goes offline
  Meteor.users.find({'status.online': true}).observe
    removed: (user) ->
      Meteor.users.update(user._id, {$set : {'status.curatorInboxSourceId': null}})

  # Ensure promed feed exists
  promedFeed = Feeds.findOne(url: 'promedmail.org/post/')
  if not promedFeed?.title
    newFeedProps =
      title: 'ProMED-mail'
      url: 'promedmail.org/post/'
    feedSchema.validate(newFeedProps)
    Feeds.upsert promedFeed?._id,
      $set: newFeedProps
      $setOnInsert:
        addedDate: new Date()

  updateDatabase()

  # Validate incidents
  if Meteor.isDevelopment
    console.log "starting incident validation"
    incidentOffset = 0
    validateIncidents = ->
      noMoreIncidents = true
      Incidents.find({
        deleted: {$in: [null, false]}
      }, {
        skip: incidentOffset
        limit: 100
      }).forEach (incident)->
        incidentOffset++
        noMoreIncidents = false
        try
          incidentReportSchema.validate(incident)
        catch error
          console.log error
          console.log JSON.stringify(incident, 0, 2)
      if noMoreIncidents
        console.log "incidents validated"
        Meteor.clearInterval(interval)
    interval = Meteor.setInterval(validateIncidents, 20000)

  if not Meteor.isAppTest
    Meteor.setInterval(autoprocessArticles, 100000)

  # If a remote EIDR-C instance url is provided, periodically pull data from it.
  if process.env.ONE_WAY_SYNC_URL
    # Do initial sync on startup
    Meteor.setTimeout(syncCollection, 1000)
    # Pull data every 6 hours
    Meteor.setInterval(syncCollection, 6 * 60 * 60 * 1000)

  Meteor.setInterval updateAutoEvents, 60 * 60 * 1000
  updateAutoEvents()

  Meteor.setInterval ->
    # Pull in the latest ProMED posts for processing.
    Meteor.call('fetchPromedPosts',
      startDate: moment().subtract(2, 'days').toDate()
      endDate: new Date()
    )
  , 5 * 60 * 60 * 1000

  console.log "Syncing structured data feeds"
  syncStructuredFeeds()
