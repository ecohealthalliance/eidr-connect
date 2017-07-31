import EventIncidents from '/imports/collections/eventIncidents'

Template.intervalDetailsModal.events
  'click .view-incident': (event, instance) ->
    incidentId = $(event.currentTarget).data('id')
    Modal.hide('intervalDetailsModal')
    if incidentId
      Meteor.setTimeout ->
        Modal.show 'incidentModal',
          incident: EventIncidents.findOne(incidentId)
      , 300
