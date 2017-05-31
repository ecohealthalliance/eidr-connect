import { annotateContentWithIncidents } from '/imports/ui/annotation'
import Incidents from '/imports/collections/incidentReports.coffee'

Template.annotatedContent.onCreated ->
  @scrolled = new ReactiveVar(false)

Template.annotatedContent.helpers
  annotatedContent: ->
    selectedAnnotationId = Template.instance().data.selectedAnnotationId.get()
    annotateContentWithIncidents(@content, @incidents.fetch().map((incident)->
      if not incident.accepted
        incident.uncertainCountType = true
      incident
    ), selectedAnnotationId)

Template.annotatedContent.events
  'mouseup .selectable-content': (event, instance) ->
    instanceData = instance.data
    selection = window.getSelection()
    instance.scrolled.set(false)
    if not selection.isCollapsed and selection.toString().trim()
      data =
        source: instanceData.source
        scrolled: instance.scrolled
        view: 'newIncidentFromSelection'
        relatedElements: instanceData.relatedElements
      Blaze.renderWithData(
        Template.popup,
        data,
        $("#{instanceData.relatedElements.parent}")[0]
        $("#{instanceData.relatedElements.sibling}")[0]
      )
    else
      $currentTarget = $(event.currentTarget)
      # Temporarily 'shuffle' the text layers so selectable-content is on
      # bottom and annotated-content is on top
      $currentTarget.css('z-index', -1)
      # Get element based on location of click event
      elementAtPoint = document.elementFromPoint(event.clientX, event.clientY)
      annotationId = elementAtPoint.getAttribute('data-incident-id')
      if elementAtPoint.classList.contains('accepted')
        # Set reactive variable that's handed down from curatorSourceDetails and
        # shared with the incidentTable templates to the clicked annotation's ID
        instanceData.selectedAnnotationId.set(annotationId)
        data =
          incidentId: annotationId
          source: instanceData.source
          scrolled: instance.scrolled
          selectedIncidents: instanceData.selectedIncidents
          relatedElements: instanceData.relatedElements
          allowRepositioning: false
          view: 'annotationOptions'

        Blaze.renderWithData(
          Template.popup,
          data,
          $("#{instance.data.relatedElements.parent}")[0]
          $("#{instance.data.relatedElements.sibling}")[0]
        )
      else if elementAtPoint.classList.contains('uncertain')
        source = instanceData.source
        incident = Incidents.findOne(annotationId)
        snippetHtml = buildAnnotatedIncidentSnippet(
          source.enhancements.source.cleanContent.content, incident
        )
        Modal.show 'suggestedIncidentModal',
          articleId: source._id
          incident: incident
          incidentText: Spacebars.SafeString(snippetHtml)
          offCanvasStartPosition: 'top'
          showBackdrop: true
      # Return selectable-content to top so user can make selection
      $currentTarget.css('z-index', 3)
