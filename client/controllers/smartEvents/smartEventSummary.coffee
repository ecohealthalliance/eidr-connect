SmartEvents = require '/imports/collections/smartEvents.coffee'
import { formatLocation } from '/imports/ui/helpers'

Template.smartEventSummary.onCreated ->
  @copied = new ReactiveVar(false)
  @collapsed = new ReactiveVar(false)

Template.smartEventSummary.onRendered ->
  @autorun =>
    SmartEvents.findOne(@data._id)
    Meteor.defer =>
      metadataContainerHeight = 0
      $summary = @$('.summary')
      $summary.removeAttr('style')
      $('.event--metadata').children().each (key, child) ->
        metadataContainerHeight += $(child).height()
      if $summary.height() > metadataContainerHeight
        $summary.css('max-height', metadataContainerHeight)
        @collapsed.set(true)
      else
        @collapsed.set(false)

Template.smartEventSummary.helpers
  copied: ->
    Template.instance().copied.get()

  collapsed: ->
    Template.instance().collapsed.get()

  locationNames: ->
    formattedLocations = []
    for location in Template.instance().data.locations
      formattedLocations.push(formatLocation(location))
    formattedLocations.join('; ')

Template.smartEventSummary.events
  'click .copy-link': (event, instance) ->
    copied = instance.copied
    copied.set(true)
    setTimeout ->
      copied.set(false)
    , 1000

  'click .expand': (event, instance) ->
    instance.collapsed.set(false)
    instance.$('.summary').removeAttr('style')
