Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
UserEventSchema = require '/imports/schemas/userEvent.coffee'

checkPermission = (userId) ->
  if not Roles.userIsInRole(userId, ['admin'])
    throw new Meteor.Error('auth', 'User does not have permission to create incidents')

Meteor.methods
  upsertUserEvent: (userEvent) ->
    user = Meteor.user()
    checkPermission(user._id)
    now = new Date()
    eventName = userEvent.eventName
    if UserEvents.findOne(eventName: eventName, _id: $ne: userEvent._id)
      throw new Meteor.Error('duplicate_entry', "#{eventName} already exists.")
    userEvent = _.extend userEvent,
      lastModifiedDate: now
      lastModifiedByUserId: user._id
      lastModifiedByUserName: user.profile.name
    eventId = userEvent._id
    UserEventSchema.validate(userEvent)
    UserEvents.upsert eventId,
      $set: _.omit(userEvent, "_id")
      $setOnInsert:
        creationDate: now
        createdByUserId: user._id
        createdByUserName: user.profile.name

  deleteUserEvent: (id) ->
    checkPermission(@userId)
    updateOperator =
      $set:
        deleted: true
        deletedDate: new Date()
    UserEvents.update id, updateOperator
    Incidents.update {
      userEventId: id
      deleted: $in: [ null, false ]
    }, updateOperator, multi: true

  editUserEventLastModified: (id) ->
    user = Meteor.user()
    if user
      UserEvents.update id,
        $set:
          lastModifiedDate: new Date(),
          lastModifiedByUserId: user._id,
          lastModifiedByUserName: user.profile.name

  editUserEventLastIncidentDate: (id) ->
    incidentIds = _.pluck(UserEvents.findOne(id).incidents, 'id')
    latestEventIncident = Incidents.findOne
      _id: $in: incidentIds
      deleted: $in: [null, false]
      {sort: 'dateRange.end': -1}
    if latestEventIncident
      UserEvents.update id,
        $set:
          lastIncidentDate: latestEventIncident.dateRange.end
    else
      UserEvents.update id,
        $unset:
          lastIncidentDate: ''
