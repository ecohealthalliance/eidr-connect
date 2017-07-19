Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'

Template.eventDetails.helpers
  formatDate: (date) ->
    moment(date).format('MMM D, YYYY')

  getUserName: (prop) ->
    Meteor.users.findOne(
      Template.instance().data.userEvent[prop]
    )?.profile.name

Template.eventDetails.events
  'click .edit-event': (event, instance) ->
    Modal.show 'editEventDetailsModal',
      event: instance.data.userEvent