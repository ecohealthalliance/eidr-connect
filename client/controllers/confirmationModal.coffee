Template.confirmationModal.onCreated ->
  console.log @data

Template.confirmationModal.events
  'click .confirm': (event, instance) ->
    instance.data.onConfirm()
    Modal.hide(instance)
