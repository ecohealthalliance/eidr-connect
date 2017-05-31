Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'

Template.summary.onCreated ->
  @copied = new ReactiveVar(false)
  @collapsed = new ReactiveVar(false)

Template.summary.onRendered ->
  @autorun =>
    UserEvents.findOne(@data._id)
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

Template.summary.helpers
  formatDate: (date) ->
    moment(date).format('MMM D, YYYY')

  copied: ->
    Template.instance().copied.get()

  collapsed: ->
    Template.instance().collapsed.get()

Template.summary.events
  'click .copy-link': (event, instance) ->
    copied = instance.copied
    copied.set(true)
    setTimeout ->
      copied.set(false)
    , 1000

  'click .expand': (event, instance) ->
    instance.collapsed.set(false)
    instance.$('.summary').removeAttr('style')
