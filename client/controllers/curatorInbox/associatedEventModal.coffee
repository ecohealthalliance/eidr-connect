UserEvents = require '/imports/collections/userEvents.coffee'
Template.associatedEventModal.helpers
  associatedEvents: ->
    UserEvents.find('incidents.id': @incidentId)

Template.associatedEventModal.events
  'click .remove': (event, instance)->
    Meteor.call('removeIncidentFromEvent', instance.data.incidentId, @_id)
