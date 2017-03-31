Incidents = require '/imports/collections/incidentReports.coffee'

findIncident = (accepted) ->
  query = {}
  query.url = $regex: new RegExp("#{Template.instance().data.source._sourceId}$")
  if accepted
    query.accepted = $eq: true
  else if not _.isUndefined(accepted)
    query.accepted = $ne: true
  Incidents.findOne(query)

Template.sourceIncidentReports.onCreated ->
  @tableContentScrollable = new ReactiveVar(true)

Template.sourceIncidentReports.helpers
  tableContentScrollable: ->
    Template.instance().tableContentScrollable

  tableContentIsScrollable: ->
    Template.instance().tableContentScrollable.get()

  hasAcceptedIncidents: ->
    findIncident(true)

  hasRejectedIncidents: ->
    findIncident(false)

  hasIncidents: ->
    findIncident()
