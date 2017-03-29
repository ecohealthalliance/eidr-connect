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
  $(@data.relatedElements.sourceContainer).on 'scroll', (event) =>
    unless @scrolled.get()
      @scrolled.set(true)

Template.annotatedContent.onDestroyed ->
  $('body').off('mousedown')

Template.annotatedContent.helpers
  annotatedContent: ->
    annotateContentWithIncidents(@content, @incidents.fetch())

Template.annotatedContent.events
  'mouseup .selectable-content': _.debounce (event, instance) ->
      selection = window.getSelection()
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
