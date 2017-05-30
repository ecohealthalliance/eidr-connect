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
  @showBackdrop = @data.showBackdrop
  @showBackdrop ?= false
  @incident = @data.incident or {}
  @incident.suggestedFields = new ReactiveVar(@incident.suggestedFields or [])
  @valid = new ReactiveVar(false)
  @modals =
    currentModal: element: '#suggestedIncidentModal'
    previousModal:
      element: '#suggestedIncidentsModal'
      add: 'fade'

  @editIncident = (incident, userEventId) =>
    method = 'addIncidentReport'
    action = 'added'
    if @incident._id
      method = 'editIncidentReport'
      action = 'updated'

    incident.annotations = @data.incident?.annotations
    incident = _.pick(incident, incidentReportSchema.objectKeys())
    Meteor.call method, incident, userEventId, (error, result) =>
      if error
        return notify('error', error)
      notify('success', "Incident #{action}.")
      stageModals(@, @modals)

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

  showBackdrop: ->
    Template.instance().showBackdrop.toString()

  saveButtonText: ->
    buttonText = 'Confirm'
    instanceData = Template.instance().data
    if instanceData.incident._id
      buttonText = 'Save'
      unless instanceData.incident.accepted
        buttonText += ' & Accept'
    buttonText += ' Incident'
    buttonText

Template.suggestedIncidentModal.events
  'hide.bs.modal #suggestedIncidentModal': (event, instance) ->
    if $(event.currentTarget).hasClass('in')
      event.preventDefault()
      stageModals(instance, instance.modals)

  'click .reject': (event, instance) ->
    instanceData = instance.data
    if instanceData.incidentCollection
      instanceData.incidentCollection.update instance.incident._id,
        $set:
          accepted: false
    else
      Meteor.call 'updateIncidentReport', {
        _id: instance.incident._id
        accepted: false
      }, (error, result) =>
        if error
          toastr.error "Error: " + error
    stageModals(instance, instance.modals)

  'click .cancel': (event, instance) ->
    stageModals(instance, instance.modals)

  'click .save-modal': (event, instance) ->
    # Submit the form to trigger validation and to update the 'valid'
    # reactiveVar — its value is based on whether the form's hidden submit
    # button's default is prevented
    instanceData = instance.data
    $('#add-incident').submit()
    return unless instance.valid.get()
    incident = utils.incidentReportFormToIncident(instance.$("form")[0])

    return if not incident
    incident.suggestedFields = instance.incident.suggestedFields.get()
    incident.accepted = true
    incident = _.extend({}, instanceData.incident, incident)
    if instanceData.incidentCollection
      delete incident._id
      instanceData.incidentCollection.update instance.incident._id,
        $unset:
          cases: true
          deaths: true
          specify: true
        $set: incident
      notify('success', 'Incident Accepted', 1200)
      stageModals(instance, instance.modals)
    else
      incident = _.extend({}, instance.data.incident, incident)
      instance.editIncident(incident, instanceData.userEventId)
