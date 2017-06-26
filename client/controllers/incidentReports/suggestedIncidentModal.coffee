import UserEvents from'/imports/collections/userEvents.coffee'
import incidentReportSchema from '/imports/schemas/incidentReport.coffee'
import utils from '/imports/utils.coffee'
import { notify } from '/imports/ui/notification'
import { stageModals } from '/imports/ui/modals'

Template.suggestedIncidentModal.onRendered ->
  Meteor.defer =>
    # Add max-height to snippet if it is taller than form
    formHeight = @$('.add-incident--wrapper').height()
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
    if incident._id
      method = 'editIncidentReport'
      action = 'updated'

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
    incidentId = instance.incident._id
    if instanceData.incidentCollection
      instanceData.incidentCollection.update incidentId,
        $set:
          accepted: false
      stageModals(instance, instance.modals)
    else
      incidentIds = [incidentId]
      deleteSelectedIncidents = ->
        Meteor.call 'deleteIncidents', incidentIds, (error, result) ->
          if error
            notify('error', 'There was a problem updating your incidents.')
          stageModals(instance, instance.modals)
      if UserEvents.find('incidents.id': $in: incidentIds).count() > 0
        Modal.show 'confirmationModal',
          primaryMessage: 'There are events associated with this incident.'
          secondaryMessage: """
            If the incident is deleted, the associations will be lost.
            Are you sure you want to delete it?
          """
          icon: 'trash-o'
          onConfirm: deleteSelectedIncidents
      else
        deleteSelectedIncidents()

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
    incident.accepted = true
    incident._id = instance.incident._id
    unless incident._id
      incident = _.extend({}, instanceData.incident, incident)
    if instanceData.incidentCollection
      incident.suggestedFields = instance.incident.suggestedFields.get()
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
      instance.editIncident(
        incidentReportSchema.clean(incident),
        instanceData.userEventId
      )
