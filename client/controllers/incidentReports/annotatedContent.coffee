{ annotateContentWithIncidents } = require('/imports/ui/annotation')

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
    annotateContentWithIncidents(@content, @incidents.fetch(), selectedAnnotationId)

Template.annotatedContent.events
  'mouseup .selectable-content': _.debounce (event, instance) ->
    selection = window.getSelection()
    instance.scrolled.set(false)
    if not selection.isCollapsed
      data =
        source: instance.data.source
        scrolled: instance.scrolled
        selecting: instance.selecting
        popupDelay: POPUP_DELAY
      Blaze.renderWithData(
        Template.newIncidentFromSelection,
        data,
        $("#{instance.data.relatedElements.parent}")[0]
        $("#{instance.data.relatedElements.sibling}")[0]
      )
  , POPUP_DELAY

  'mousedown .selectable-content': (event, instance) ->
    $currentTarget = $(event.currentTarget)
    # Temporarily 'shuffle' the text layers so selectable-content is on
    # bottom and annotated-content is on top
    $currentTarget.css('z-index', -1)
    # Get element based on location of click event
    elementAtPoint = document.elementFromPoint(event.clientX, event.clientY)
    if elementAtPoint.nodeName is 'SPAN'
      # Set reactive variable that's handed down from curatorSourceDetails and
      # shared with the incidentTable templates to the clicked annotation's ID
      annotationId = elementAtPoint.getAttribute('data-incident-id')
    else
      # if clicked elsewhere, clear selection
      annotationId = null
    instance.data.selectedAnnotationId.set(annotationId)
    # Return selectable-content to top so user can make selection
    $currentTarget.css('z-index', 3)
