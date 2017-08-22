import notify from '/imports/ui/notification'

Template.deleteConfirmationModalBody.events
  'click .confirm-deletion': (event, instance) ->
    event.preventDefault()
    data = instance.data
    id = data.objId
    objNameToDelete = data.objNameToDelete
    Modal.hide()
    $('body').removeClass('modal-open')
    $('.modal-backdrop').remove()
    switch objNameToDelete
      when 'event'
        Meteor.call 'deleteUserEvent', id, (error, result) ->
          if error
            notify('error', error.message)
          else
            notify('success', "The #{objNameToDelete} has been deleted.")
        Router.go 'events', _view: 'curated'
      when 'smartEvent'
        Meteor.call 'deleteSmartEvent', id, (error, result) ->
          if error
            notify('error', error.message)
          else
            notify('success', "The #{objNameToDelete} has been deleted.")
        Router.go 'events', _view: 'smart'