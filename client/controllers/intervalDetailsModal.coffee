import EventIncidents from '/imports/collections/eventIncidents'

Template.intervalDetailsModal.events
  'click .view-incident': (event, instance) ->
    console.log event.target, event.currentTarget, $(event.currentTarget).data()
    incidentId = $(event.currentTarget).data('id')
    Modal.hide()
    if incidentId
      Modal.show 'incidentModal',
        incident: EventIncidents.findOne(incidentId)
