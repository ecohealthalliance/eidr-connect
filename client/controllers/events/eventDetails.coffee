Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'

Template.eventDetails.onCreated ->
  @copied = new ReactiveVar(false)
  event = @data.event

Template.eventDetails.onRendered ->
  @autorun =>
    UserEvents.findOne(@data._id)

Template.eventDetails.helpers
  formatDate: (date) ->
    moment(date).format('MMM D, YYYY')

  copied: ->
    Template.instance().copied.get()

  getUserName: (prop) ->
    Meteor.users.findOne(
      Template.instance().data.event[prop]
    )?.profile.name

Template.eventDetails.events
  'click .copy-link': (event, instance) ->
    copied = instance.copied
    copied.set(true)
    setTimeout ->
      copied.set(false)
    , 1000
