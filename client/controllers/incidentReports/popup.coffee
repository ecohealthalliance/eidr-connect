POPUP_DELAY = 150
POPUP_PADDING = 5
POPUP_PADDING_TOP = 20
POPUP_WINDOW_PADDING = 100

Template.popup.onCreated ->
  @selection = window.getSelection()
  @showPopup = new ReactiveVar(true)
  @popupPosition = new ReactiveVar(null)
  @nearBottom = new ReactiveVar(false)
  @allowRepositioning = @data.allowRepositioning
  @allowRepositioning ?= true

  range = @selection.getRangeAt(0)
  {top, bottom, left, width} = range.getBoundingClientRect()
  selectionHeight = bottom - top
  topPosition = "#{Math.floor(top + selectionHeight + POPUP_PADDING)}px"
  bottomPosition = 'auto'
  # Handle case when selection is near bottom of window
  if (bottom + POPUP_WINDOW_PADDING) > window.innerHeight
    topPosition = 'auto'
    bottomPosition = "#{window.innerHeight - top + POPUP_PADDING_TOP}px"
    @nearBottom.set(true)
  @popupPosition.set
    top: topPosition
    bottom: bottomPosition
    left:  "#{Math.floor(left + width / 2)}px"

  $('body').on 'mousedown', (event) =>
    # Allow event to propagate to 'add-incident-from-selection' button before
    # element is removed from DOM
    delay = 0
    if event.target.parentElement.nodeName in ['BUTTON', 'LI', 'UL']
      delay = POPUP_DELAY
    Meteor.setTimeout =>
      @showPopup.set(false)
    , delay

  $(@data.relatedElements.sourceContainer).on 'scroll', _.throttle (event) =>
    unless @data.scrolled.get()
      @data.scrolled.set(true)
  , 100


Template.popup.onRendered ->
  Meteor.setTimeout =>
    @$('.popup').addClass('active')
  , POPUP_DELAY

  @autorun =>
    if not @showPopup.get()
      @$('.popup').remove()
      @data.scrolled.set(false)

  @autorun =>
    if @data.scrolled.get()
      if @allowRepositioning
        @popupPosition.set
          width: '100%'
          top: "#{$('.curator-source-details--actions').outerHeight()}px"
          left: "auto"
          bottom: 'auto'
      else
        @showPopup.set(false)

Template.popup.helpers
  position: ->
    Template.instance().popupPosition.get()

  scrolled: ->
    Template.instance().data.scrolled.get()

  nearBottom: ->
    Template.instance().nearBottom.get()

Template.popup.onDestroyed ->
  $('body').off('mousedown')
