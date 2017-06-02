import { buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'
import { createIncidentReportsFromEnhancements } from '/imports/utils.coffee'

POPUP_DELAY = 200
POPUP_PADDING = 5
POPUP_PADDING_TOP = 20
POPUP_WINDOW_PADDING = 100

Template.popup.onCreated ->
  @selection = window.getSelection()
  @data.showPopup.set(true)
  @popupPosition = new ReactiveVar(null)
  @nearBottom = new ReactiveVar(false)

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

Template.popup.onRendered ->
  Meteor.setTimeout =>
    @$('.popup').addClass('active')
  , @data.popupDelay or POPUP_DELAY

  @autorun =>
    if not @data.showPopup.get()
      @$('.popup').remove()
      @data.scrolled.set(false)

  @autorun =>
    if @data.scrolled.get()
      @popupPosition.set
        width: '100%'
        top: "#{$('.curator-source-details--actions').outerHeight()}px"
        left: "auto"
        bottom: 'auto'

Template.popup.helpers
  position: ->
    Template.instance().popupPosition.get()

  scrolled: ->
    Template.instance().data.scrolled.get()

  nearBottom: ->
    Template.instance().nearBottom.get()
