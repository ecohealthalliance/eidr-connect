import incidentReportSchema from '/imports/schemas/incidentReport.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import Articles from '/imports/collections/articles.coffee'
import autoprocessArticles from '/server/autoprocess.coffee'
import updateDatabase from '/server/updaters.coffee'

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
