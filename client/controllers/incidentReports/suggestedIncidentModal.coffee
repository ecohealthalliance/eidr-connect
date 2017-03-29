utils = require '/imports/utils.coffee'
incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
{ notify } = require '/imports/ui/notification'
{ stageModals } = require '/imports/ui/modals'

Template.suggestedIncidentModal.onRendered ->
  instance = @
  Meteor.defer ->
    # Add max-height to snippet if it is taller than form
    formHeight = instance.$('.add-incident--wrapper').height()
    $snippet = $('.snippet--text')
    if $snippet.height() > formHeight
      $snippet.css('max-height', formHeight)

Template.suggestedIncidentModal.onCreated ->
  @incidentCollection = @data.incidentCollection
  @incident = @data.incident or {}
  @incident.suggestedFields = new ReactiveVar(@incident.suggestedFields or [])
  @valid = new ReactiveVar(false)
  @modals =
    currentModal: element: '#suggestedIncidentModal'
    previousModal:
      element: '#suggestedIncidentsModal'
      add: 'fade'

Template.suggestedIncidentModal.onDestroyed ->
  $('#suggestedIncidentModal').off('hide.bs.modal')

Template.suggestedIncidentModal.helpers
  hasSuggestedFields: ->
    Template.instance().incident.suggestedFields.get()

  type: -> [ 'case', 'date', 'location', 'disease' ]

  valid: ->
    Template.instance().valid

  offCanvasStartPosition: ->
    Template.instance().data.offCanvasStartPosition or 'right'

Template.suggestedIncidentModal.events
  'hide.bs.modal #suggestedIncidentModal': (event, instance) ->
    if $(event.currentTarget).hasClass('in')
      event.preventDefault()
      stageModals(instance, instance.modals)

  'click .reject': (event, instance) ->
    stageModals(instance, instance.modals)
    Template.instance().incidentCollection.update instance.incident._id,
      $set:
        accepted: false

  'click .save-modal': (event, instance) ->
    # Submit the form to trigger validation and to update the 'valid'
    # reactiveVar — its value is based on whether the form's hidden submit
    # button's default is prevented
    $('#add-incident').submit()
    return unless instance.valid.get()
    incident = utils.incidentReportFormToIncident(instance.$("form")[0])

    return if not incident
    incident.suggestedFields = instance.incident.suggestedFields.get()
    incident.userEventId = instance.data.userEventId
    incident.accepted = true
    if instance.incidentCollection
      instance.incidentCollection.update instance.incident._id,
        $unset:
          cases: true
          deaths: true
          specify: true
        $set: incident
      notify('success', 'Incident Report Accepted', 1200)
      stageModals(instance, instance.modals)
    else
      incident.annotations = instance?.incident?.annotations
      incident = _.pick(incident, incidentReportSchema.objectKeys())
      Meteor.call 'addIncidentReport', incident, (error, result) ->
        if error
          return notify('error', error)
        notify('success', 'Incident report added.')
        stageModals(instance, instance.modals)
