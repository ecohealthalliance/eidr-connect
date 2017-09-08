Template.eventDetails.events
  'click .edit-event': (event, instance) ->
    if @isUserEvent
      Modal.show 'editEventDetailsModal',
        event: instance.data.event
    else
      Modal.show 'editSmartEventDetailsModal',
        event: instance.data.event
