utils = require '/imports/utils.coffee'
validator = require 'bootstrap-validator'
{ notify } = require '/imports/ui/notification'
{ stageModals } = require '/imports/ui/modals'

Template.incidentModal.onCreated ->
  @valid = new ReactiveVar(false)
  @submitting = new ReactiveVar(false)
  @modals =
    currentModal: element: '.incident-report'
    previousModal:
      element: '#suggestedIncidentsModal'
      add: 'fade'

Template.incidentModal.onRendered ->
  instance = @
  $('.incident-report').on 'hide.bs.modal', (event) ->
    $modal = $(event.currentTarget)
    if $modal.hasClass('off-canvas--right') and not $modal.hasClass('out')
      stageModals(instance, instance.modals)
      event.preventDefault()

Template.incidentModal.onDestroyed ->
  $('.incident-report').off('hide.bs.modal')

Template.incidentModal.helpers
  valid: ->
    Template.instance().valid

  classNames: ->
    classNames = ''
    offCanvas = Template.instance().data.offCanvas
    if offCanvas
      classNames += "transparent-backdrop off-canvas--#{offCanvas}"
    else
      classNames += 'fade'
    classNames

  submitting: ->
    Template.instance().submitting.get()

Template.incidentModal.events
  'click .save-incident, click .save-incident-duplicate': (event, instance) ->
    # Submit the form to trigger validation and to update the 'valid'
    # reactiveVar — its value is based on whether the form's hidden submit
    # button's default is prevented
    instance.submitting.set(true)
    $('#add-incident').submit()
    return unless instance.valid.get()
    duplicate = $(event.target).hasClass('save-modal-duplicate')
    form = instance.$('form')[0]
    incident = utils.incidentReportFormToIncident(form)
    instanceData = instance.data

    if not incident
      return

    if instance.data.accept or @incident?.accepted
      incident.accepted = true

    manualAnnotation = instanceData.manualAnnotation
    if manualAnnotation
      incident.annotations ?= {}
      incident.annotations.case = [manualAnnotation]

    if @add
      Meteor.call 'addIncidentReport', incident, instanceData.userEventId, (error, result) ->
        if not error
          $('.reactive-table tr').removeClass('open')
          $('.reactive-table tr.tr-details').remove()
          if !duplicate
            form.reset()
            notify('success', 'Incident added.')
            if instance.data.offCanvas
              stageModals(instance, instance.modals)
            else
              Modal.hide('incidentModal')
        else
          errorString = error.reason
          if error.details[0].name is 'locations' and error.details[0].type is 'minCount'
            errorString = 'You must specify at least one loction'
          notify('error', errorString)
        instance.submitting.set(false)

    if @edit
      _incident = _.extend({}, @incident, incident)

      # Remove existing type props if user changes incident type
      fieldsToRemove = []
      if incident.cases
        fieldsToRemove = ['deaths', 'specify']
      else if incident.deaths
        fieldsToRemove = ['cases', 'specify']
      else if incident.specify
        fieldsToRemove = ['cases', 'deaths']
      fieldsToRemove.forEach (field) ->
        delete _incident[field]

      Meteor.call 'updateIncidentReport', _incident, fieldsToRemove, (error, result) ->
        if not error
          $('.reactive-table tr').removeClass('open')
          $('.reactive-table tr.details').remove()
          notify('success', 'Incident updated')
          Modal.hide('incidentModal')
        else
          notify('error', error.reason)
        instance.submitting.set(false)
