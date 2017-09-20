import utils from '/imports/utils.coffee'
import notify from '/imports/ui/notification'
import { stageModals } from '/imports/ui/modals'

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

  edit: ->
    Template.instance().data.incident?._id

Template.incidentModal.events
  'click .save-incident, click .save-incident-duplicate': (event, instance) ->
    # Submit the form to trigger validation and to update the 'valid'
    # reactiveVar — its value is based on whether the form's hidden submit
    # button's default is prevented
    $('#add-incident').submit()
    return if not instance.valid.get()
    form = instance.$('form')[0]
    incident = utils.incidentReportFormToIncident(form)
    instanceData = instance.data

    if not incident
      return

    instance.submitting.set(true)

    if instance.data.accept or @incident?.accepted
      incident.accepted = true

    manualAnnotation = instanceData.manualAnnotation
    if manualAnnotation
      incident.annotations ?= {}
      incident.annotations.case = [manualAnnotation]

    if @incident?._id
      incident._id = @incident._id
      Meteor.call 'editIncidentReport', incident, (error, result) ->
        if not error
          $('.reactive-table tr').removeClass('open')
          $('.reactive-table tr.details').remove()
          notify('success', 'Incident updated')
          Modal.hide('incidentModal')
        else
          notify('error', error.reason)
        instance.submitting.set(false)
    else
      Meteor.call 'addIncidentReport', incident, instanceData.userEventId, (error, result) ->
        if not error
          $('.reactive-table tr').removeClass('open')
          $('.reactive-table tr.tr-details').remove()
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

  'click .delete-incident': (event, instance) ->
    Meteor.call 'deleteIncidents', [@incident._id], (error, result) ->
      if error
        notify('error', error.reason)
        return
      notify('success', 'Incident Deleted')
      Modal.hide()
