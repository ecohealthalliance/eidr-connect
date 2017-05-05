incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
Articles = require '/imports/collections/articles.coffee'

Meteor.startup ->
  # Clean-up curatorInboxSourceId when user goes offline
  Meteor.users.find({'status.online': true}).observe
    removed: (user) ->
      Meteor.users.update(user._id, {$set : {'status.curatorInboxSourceId': null}})

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
