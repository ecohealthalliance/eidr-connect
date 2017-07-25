import EventIncidents from '/imports/collections/eventIncidents'

Template.intervalDetailsModal.events
  'click .view-incident': (event, instance) ->
    console.log event.target, event.currentTarget, $(event.currentTarget).data()
    incidentId = $(event.currentTarget).data('id')
    Modal.hide('intervalDetailsModal')
    if incidentId
      Meteor.setTimeout ->
        Modal.show 'incidentModal',
          incident: EventIncidents.findOne(incidentId)
      , 300
