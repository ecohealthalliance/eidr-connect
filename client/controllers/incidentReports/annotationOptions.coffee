import Incidents from '/imports/collections/incidentReports.coffee'
import { buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'

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
    Modal.show 'deleteConfirmationModal',
      objNameToDelete: 'incident'
      objId: instance.data.incidentId
      displayName: instance.incident.annotations.case[0].text
