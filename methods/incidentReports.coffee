import incidentReportSchema from '/imports/schemas/incidentReport.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import UserEvents from '/imports/collections/userEvents.coffee'
import Articles from '/imports/collections/articles.coffee'

checkPermission = (userId) ->
  if not Roles.userIsInRole(userId, ['admin'])
    throw new Meteor.Error('auth', 'User does not have permission to create incidents')

Meteor.methods
  addIncidentReport: (incident, userEventId) ->
    checkPermission(@userId)
    user = Meteor.user()
    incidentReportSchema.validate(incident)
    incident.addedByUserId = user._id
    incident.addedByUserName = user.profile.name
    incident.addedDate = new Date()
    newId = Incidents.insert(incident)
    if userEventId
      Meteor.call('addIncidentToEvent', userEventId, newId)
    return newId

  editIncidentReport: (incident) ->
    checkPermission(@userId)
    user = Meteor.user()
    incidentReportSchema.validate(incident)

    # Remove existing type props if user changes incident type and merge incident
    # from client with existing incident
    if incident.cases >= 0
      fieldsToRemove = deaths: true, specify: true
    else if incident.deaths >= 0
      fieldsToRemove = cases: true, specify: true
    else if incident.specify
      fieldsToRemove = cases: true, deaths: true
    unless incident.status
      fieldsToRemove ?= {}
      fieldsToRemove.status = true

    existingIncident = Incidents.findOne(incident._id)
    updatedIncident = _.extend({}, existingIncident, incident)
    updateOperators = {}
    if fieldsToRemove
      updateOperators = $unset: fieldsToRemove
      for type of fieldsToRemove
        delete updatedIncident[type]

    updatedIncident.modifiedByUserId = user._id
    updatedIncident.modifiedByUserName = user.profile.name
    updatedIncident.modifiedDate = new Date()
    res = Incidents.update(updatedIncident._id, updatedIncident, updateOperators)
    if incident.userEventId
      Meteor.call("editUserEventLastModified", incident.userEventId)
      Meteor.call("editUserEventLastIncidentDate", incident.userEventId)
    return incident._id

  addIncidentReports: (incidents, userEventId) ->
    checkPermission(@userId)
    incidents.map (incident)->
      Meteor.call('addIncidentReport', incident, userEventId)

  deleteIncidents: (incidentIds)->
    checkPermission(@userId)
    Incidents.update({
      _id: $in: incidentIds
    }, {
      $set: accepted: false
    }, {
      multi: true
    })
    userEventIds = UserEvents.find(
      'incidents.id': $in: incidentIds
    ).map((x)->x._id)
    UserEvents.update({
      'incidents.id': $in: incidentIds
    }, {
      $pull:
        incidents:
          id:
            $in: incidentIds
    }, {
      multi: true
    })
    userEventIds.map (userEventId)->
      Meteor.call('editUserEventLastModified', userEventId)
      Meteor.call('editUserEventLastIncidentDate', userEventId)

  removeIncidentFromEvent: (incidentId, userEventId) ->
    checkPermission(@userId)
    event = UserEvents.findOne(userEventId)
    if event
      _incidents = _.filter event.incidents, (incident) ->
        incident.id != incidentId
      UserEvents.update 'incidents.id': incidentId,
        $set: incidents: _incidents
      Meteor.call('editUserEventLastModified', userEventId)
      Meteor.call('editUserEventLastIncidentDate', userEventId)

  addIncidentToEvent: (userEventId, incidentId) ->
    checkPermission(@userId)
    eventWithIncident = UserEvents.findOne
      _id: userEventId
      'incidents.id': incidentId
    if not eventWithIncident
      UserEvents.update userEventId,
        $push:
          incidents:
            id: incidentId
            associationDate: new Date()
            associationUserId: @userId
      Meteor.call('editUserEventLastModified', userEventId)
      Meteor.call('editUserEventLastIncidentDate', userEventId)

  addIncidentsToEvent: (incidentIds, userEventId, source) ->
    checkPermission(@userId)
    existingSource = Articles.findOne(source._id)
    # If document is in collection associate with event, otherwise add to Articles
    # collection and associate
    if existingSource
      Articles.update(source._id, $addToSet: userEventIds: userEventId)
    else
      Meteor.call 'addEventSource',
        url: "promedmail.org/post/#{sourceId}"
        userEventId: userEventId
        title: source.title
        publishDate: source.publishDate
        publishDateTZ: 'EST',
        userEventId
    # Associate Incidents with Event
    incidentIds.forEach (incidentId) ->
      Meteor.call('addIncidentToEvent', userEventId, incidentId)
