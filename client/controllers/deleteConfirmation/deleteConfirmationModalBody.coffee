{ commonPostDeletionTasks } = require '/imports/ui/deletion'

Template.deleteConfirmationModalBody.events
  'click .confirm-deletion': (event, instance) ->
    event.preventDefault()
    data = instance.data
    id = data.objId
    objNameToDelete = data.objNameToDelete

    switch objNameToDelete
      when 'source'
        Meteor.call 'removeEventSource', id, data.userEventId, (error) ->
          commonPostDeletionTasks(error, objNameToDelete)
      when 'event'
        Meteor.call 'deleteUserEvent', id, (error, result) ->
          commonPostDeletionTasks(error, objNameToDelete, 'edit-event-modal')
          unless error
            Router.go 'events', _view: 'curated'
      when 'smartEvent'
        Meteor.call 'deleteSmartEvent', id, (error, result) ->
          commonPostDeletionTasks(error, objNameToDelete, 'edit-event-modal')
          unless error
            Router.go 'events', _view: 'smart'
      when 'feed'
        Meteor.call 'removeFeed', id, (error) ->
          commonPostDeletionTasks(error, objNameToDelete)
