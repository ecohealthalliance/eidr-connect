incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
Constants = require '/imports/constants.coffee'
{ regexEscape } = require '/imports/utils'

Meteor.methods
  addIncidentReport: (incident, userEventId) ->
    incidentReportSchema.validate(incident)
    user = Meteor.user()
    if not Roles.userIsInRole(user._id, ['admin'])
      throw new Meteor.Error("auth", "User does not have permission to create incidents")
    incident.addedByUserId = user._id
    incident.addedByUserName = user.profile.name
    incident.addedDate = new Date()
    newId = Incidents.insert(incident)
    if userEventId
      Meteor.call('addIncidentToEvent', userEventId, newId)
    return newId


  # similar to editIncidentReport, but allows you to set a single field without changing any other existing fields.
  updateIncidentReport: (incident) ->
    _id = incident._id
    delete incident._id
    user = Meteor.user()
    if not Roles.userIsInRole(user._id, ['admin'])
      throw new Meteor.Error("auth", "User does not have permission to edit incidents")
    incident.modifiedByUserId = user._id
    incident.modifiedByUserName = user.profile.name
    res = Incidents.update({_id: _id}, {$set: incident})
    return incident._id

  editIncidentReport: (incident, userEventId) ->
    incidentReportSchema.validate(incident)
    incidentId = incident._id
    user = Meteor.user()
    if not Roles.userIsInRole(user._id, ['admin'])
      throw new Meteor.Error("auth", "User does not have permission to edit incidents")
    incident.modifiedByUserId = user._id
    incident.modifiedByUserName = user.profile.name
    res = Incidents.update(incidentId, incident)
    if userEventId
      Meteor.call("editUserEventLastModified", userEventId)
      Meteor.call("editUserEventLastIncidentDate", userEventId)
    return incidentId

  addIncidentReports: (incidents, userEventId) ->
    incidents.map (incident)->
      Meteor.call("addIncidentReport", incident, userEventId)

  removeIncidentReport: (id) ->
    if not Roles.userIsInRole(@userId, ['admin'])
      throw new Meteor.Error("auth", "User does not have permission to edit incidents")
    incident = Incidents.findOne(id)
    Incidents.update id,
      $set:
        deleted: true,
        deletedDate: new Date()
    if incident.userEventId
      Meteor.call("editUserEventLastModified", incident.userEventId)
      Meteor.call("editUserEventLastIncidentDate", incident.userEventId)

  addIncidentToEvent: (userEventId, incidentId) ->
    userId = Meteor.user()._id
    if not Roles.userIsInRole(userId, ['admin'])
      throw new Meteor.Error("auth", "User does not have permission to create incidents")
    unless UserEvents.findOne('incidents.id': incidentId)
      UserEvents.update userEventId,
        $addToSet: incidents:
          id: incidentId
          associationDate: new Date()
          associationUserId: userId
      Meteor.call("editUserEventLastModified", userEventId)
      Meteor.call("editUserEventLastIncidentDate", userEventId)

  addIncidentsToEvent: (incidentIds, userEventId, source) ->
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
