import {
  annotateContentWithIncidents,
  buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'
import Incidents from '/imports/collections/incidentReports.coffee'

POPUP_DELAY = 100

_setSelectingState = (instance, state) ->
  instance.selecting.set(state)

Template.annotatedContent.onCreated ->
  @selecting = new ReactiveVar(false)
  @scrolled = new ReactiveVar(false)

Template.annotatedContent.onRendered ->
  $('body').on 'mousedown', (event) =>
    # Allow event to propagate to 'add-incident-from-selection' button before
    # element is removed from DOM
    setTimeout =>
      _setSelectingState(@, false)
    , POPUP_DELAY
  $(@data.relatedElements.sourceContainer).on 'scroll', _.throttle (event) =>
    unless @scrolled.get()
      @scrolled.set(true)
  , 100

Template.annotatedContent.onDestroyed ->
  $('body').off('mousedown')

Template.annotatedContent.helpers
  annotatedContent: ->
    selectedAnnotationId = Template.instance().data.selectedAnnotationId.get()
    annotateContentWithIncidents(@content, @incidents.fetch().map((incident)->
      if not incident.accepted
        incident.uncertainCountType = true
      incident
    ), selectedAnnotationId)

Template.annotatedContent.events
  'mouseup .selectable-content': _.debounce (event, instance) ->
    selection = window.getSelection()
    instance.scrolled.set(false)
    if not selection.isCollapsed and selection.toString().trim()
      data =
        source: instance.data.source
        scrolled: instance.scrolled
        selecting: instance.selecting
        popupDelay: POPUP_DELAY
        view: 'newIncidentFromSelection'
      Blaze.renderWithData(
        Template.popup,
        data,
        $("#{instance.data.relatedElements.parent}")[0]
        $("#{instance.data.relatedElements.sibling}")[0]
      )
    else
      data =
        source: instance.data.source
        scrolled: instance.scrolled
        selecting: instance.selecting
        popupDelay: POPUP_DELAY
        view: ''
      Blaze.renderWithData(
        Template.popup,
        data,
        $("#{instance.data.relatedElements.parent}")[0]
        $("#{instance.data.relatedElements.sibling}")[0]
      )
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
        instance.data.selectedAnnotationId.set(annotationId)
      else if elementAtPoint.classList.contains('uncertain')
        source = instance.data.source
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
  , POPUP_DELAY
