import incidentReportSchema from '/imports/schemas/incidentReport'
import Incidents from '/imports/collections/incidentReports'
import Articles from '/imports/collections/articles'
import autoprocessArticles from '/server/autoprocess'
import updateDatabase from '/server/updaters'
import syncCollection from '/server/oneWaySync'
import updateAutoEvents from '/server/updateAutoEvents'

Meteor.startup ->
  # Clean-up curatorInboxSourceId when user goes offline
  Meteor.users.find({'status.online': true}).observe
    removed: (user) ->
      Meteor.users.update(user._id, {$set : {'status.curatorInboxSourceId': null}})

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
