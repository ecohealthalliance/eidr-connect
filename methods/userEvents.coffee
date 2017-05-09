Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
UserEventSchema = require '/imports/schemas/userEvent.coffee'

Meteor.methods
  upsertUserEvent: (userEvent) ->
    if not Roles.userIsInRole(@userId, ['admin'])
      throw new Meteor.Error("auth", "Admin level permissions are required for this action.")
    user = Meteor.user()
    now = new Date()
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
        articleCount: 0

  deleteUserEvent: (id) ->
    if Roles.userIsInRole(Meteor.userId(), ['admin'])
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

  updateUserEventArticleCount: (id) ->
    event = UserEvents.findOne(id)
    articleCount = Articles.find(userEventIds: id).count()
    UserEvents.update(id,
      $set:
        articleCount: articleCount
    )

  editUserEventLastIncidentDate: (id) ->
    event = UserEvents.findOne(id)
    latestEventIncident = Incidents.findOne({
      userEventId: event._id
      deleted: $in: [null, false]
    }, {
      sort: 'dateRange.end': -1
    })
    if latestEventIncident
      UserEvents.update id,
        $set:
          lastIncidentDate: latestEventIncident.dateRange.end
    else
      UserEvents.update id,
        $unset:
          lastIncidentDate: ''
