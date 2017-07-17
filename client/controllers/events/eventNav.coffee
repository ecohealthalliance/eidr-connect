UserEvents = require '/imports/collections/userEvents'

Template.eventNav.events
  'click .edit-event': (event, instance) ->
    Modal.show 'editEventDetailsModal',
      event: UserEvents.findOne(Template.instance().data.userEventId)
