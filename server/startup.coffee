incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
Articles = require '/imports/collections/articles.coffee'

Meteor.startup ->
  # Clean-up curatorInboxSourceId when user goes offline
  Meteor.users.find({'status.online': true}).observe
    removed: (user) ->
      Meteor.users.update(user._id, {$set : {'status.curatorInboxSourceId': null}})

  # Validate incidents
  console.log "starting incident validation"
  incidentsToValidate = Incidents.find({deleted: {$in: [null, false]}}).fetch()

  validateIncidents = ->
    incidentsToValidate.slice(0, 100).forEach (incident)->
      try
        incidentReportSchema.validate(incident)
      catch error
        console.log error
        console.log JSON.stringify(incident, 0, 2)
    incidentsToValidate = incidentsToValidate.slice(100)
    if incidentsToValidate.length == 0
      console.log "incidents validated"
      Meteor.clearInterval(interval)
  interval = Meteor.setInterval(validateIncidents, 100000)
