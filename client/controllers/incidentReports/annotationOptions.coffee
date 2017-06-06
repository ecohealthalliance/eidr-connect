import Incidents from '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
import { buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'
import { notify } from '/imports/ui/notification'

Template.annotationOptions.onCreated ->
  data = @data
  @selectedIncidents = data.selectedIncidents
  @incident = Incidents.findOne(data.incidentId)

Template.annotationOptions.helpers
  incidentSelected: ->
    instance = Template.instance()
    Template.instance().selectedIncidents.findOne(id: @incidentId)

Template.annotationOptions.events
  'click .select': (event, instance) ->
    selectedIncidents = instance.selectedIncidents
    incidentId = instance.data.incidentId
    query = id: incidentId
    if selectedIncidents.findOne(query)
      selectedIncidents.remove(query)
    else
      selectedIncidents.insert(query)

  'click .edit': (event, instance) ->
    source = instance.data.source
    incident = instance.incident
    snippetHtml = buildAnnotatedIncidentSnippet(
      source.enhancements.source.cleanContent.content, incident
    )
    Modal.show 'suggestedIncidentModal',
      articles: [source]
      incident: incident
      incidentText: Spacebars.SafeString(snippetHtml)
      offCanvasStartPosition: 'top'
      showBackdrop: true

  'click .delete': (event, instance) ->
    incidentIds = [instance.data.incidentId]
    deleteSelectedIncidents = ->
      Meteor.call 'deleteIncidents', incidentIds, (error, result) ->
        if error
          notify('error', 'There was a problem updating your incidents.')
    if UserEvents.find('incidents.id': $in: incidentIds).count() > 0
      Modal.show 'confirmationModal',
        message: """There are events associated with this incident.
        If the incident is deleted, the associations will be lost.
        Are you sure you want to delete it?"""
        onConfirm: deleteSelectedIncidents
    else
      deleteSelectedIncidents()
