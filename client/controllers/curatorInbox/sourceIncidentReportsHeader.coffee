import Incidents from '/imports/collections/incidentReports'
UserEvents = require '/imports/collections/userEvents.coffee'
import { notify } from '/imports/ui/notification'

Template.sourceIncidentReportsHeader.onCreated ->
  @selectedIncidents = @data.selectedIncidents
  @addingEvent = new ReactiveVar(false)
  @selectedEventId = new ReactiveVar(false)

  @autorun =>
    if not @selectedIncidents.find().count()
      @addingEvent.set(false)
      @selectedEventId.set(null)

  @updateAllIncidentsStatus = (select, event) =>
    if select
      Incidents.find().forEach (incident) =>
        id = incident._id
        @selectedIncidents.upsert id: id,
          id: id
    else
      @selectedIncidents.remove({})
    event.currentTarget.blur()

Template.sourceIncidentReportsHeader.helpers
  incidentsSelectedCount: ->
    Template.instance().selectedIncidents.find().count()

  addEvent: ->
    Template.instance().addingEvent.get()

  selectedIncidents: ->
    Template.instance().selectedIncidents.find()

  allSelected: ->
    instance = Template.instance()
    selectedIncidentCount = instance.selectedIncidents.find().count()
    Incidents.find(accepted: true).count() == selectedIncidentCount

  incidents: ->
    Incidents.find()

Template.sourceIncidentReportsHeader.events
  'click .show-addEvent': (event, instance) ->
    addingEvent = instance.addingEvent
    addingEvent.set(not addingEvent.get())
    event.currentTarget.blur()

  'click .select-all': (event, instance) ->
    Template.instance().updateAllIncidentsStatus(true, event)

  'click .deselect-all': (event, instance) ->
    Template.instance().updateAllIncidentsStatus(false, event)

  'click .delete': (event, instance) ->
    selectedIncidents = instance.selectedIncidents
    selectedIncidentIds = selectedIncidents.find().map((x)->x.id)
    deleteSelectedIncidents = ->
      Meteor.call 'deleteIncidents', selectedIncidentIds, (error, result) ->
        if error
          notify('error', 'There was a problem updating your incidents.')
      selectedIncidents.remove({})
      event.currentTarget.blur()
    if UserEvents.find('incidents.id': $in: selectedIncidentIds).count() > 0
      Modal.show 'confirmationModal',
        primaryMessage: 'There are events associated with this incident.'
        secondaryMessage: """
          If the incident is deleted, the associations will be lost.
          Are you sure you want to delete it? """
        icon: 'trash-o'
        onConfirm: deleteSelectedIncidents
    else
      deleteSelectedIncidents()

  'click .select-all': (event, instance) ->
    instance.updateAllIncidentsStatus(true, event)

  'click .deselect-all': (event, instance) ->
    instance.updateAllIncidentsStatus(false, event)
