Template.editEventDetailsModal.onCreated ->
  @confirmingDeletion = new ReactiveVar false

Template.editEventDetailsModal.onRendered ->
  instance = @
  Meteor.defer ->
    @$('#editEvent').parsley()

  @$('#edit-event-modal').on 'show.bs.modal', (event) ->
    instance.confirmingDeletion.set false

Template.editEventDetailsModal.helpers
  confirmingDeletion: ->
    Template.instance().confirmingDeletion.get()

  adding: ->
    Template.instance().data.action is 'add'

Template.editEventDetailsModal.events
  'submit #editEvent': (event, instance) ->
    return if event.isDefaultPrevented() # Form is invalid
    event.preventDefault()
    name = event.target.eventName.value.trim()
    summary = event.target.eventSummary.value.trim()
    if name.length isnt 0
      Meteor.call 'upsertUserEvent',
        _id: @event._id
        eventName: name
        summary: summary
        displayOnPromed: event.target.promed.checked
      , (error, result) ->
        if not error
          Modal.hide('editEventDetailsModal')
          $('#edit-event-modal').modal('hide')

  'click .delete-event': (event, instance) ->
    instance.confirmingDeletion.set true

  'click .back-to-editing': (event, instance) ->
    instance.confirmingDeletion.set false
