SmartEvents = require '/imports/collections/smartEvents'
SmartEventSchema = require '/imports/schemas/smartEvent'

Meteor.methods
  upsertSmartEvent: (event) ->
    if not Roles.userIsInRole(@userId, ['admin'])
      throw new Meteor.Error("auth", "Admin level permissions are required for this action.")
    user = Meteor.user()
    now = new Date()
    smartEvent = _.extend event,
      lastModifiedDate: now
      lastModifiedByUserId: @userId
      lastModifiedByUserName: user.profile.name
    eventId = smartEvent._id
    SmartEventSchema.validate(smartEvent)
    SmartEvents.upsert eventId,
      $set: _.omit(smartEvent, "_id")
      $setOnInsert:
        creationDate: now
        createdByUserId: @userId
        createdByUserName: user.profile.name

  deleteSmartEvent: (id) ->
    if Roles.userIsInRole(@userId, ['admin'])
      SmartEvents.update id,
        $set:
          deleted: true,
          deletedDate: new Date()
