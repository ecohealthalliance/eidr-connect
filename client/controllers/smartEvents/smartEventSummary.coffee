SmartEvents = require '/imports/collections/smartEvents.coffee'
import { formatLocation } from '/imports/utils'

Template.smartEventSummary.helpers
  locationNames: ->
    formattedLocations = []
    for location in Template.instance().data.smartEvent.locations
      formattedLocations.push(formatLocation(location))
    formattedLocations.join('; ')

Template.smartEventSummary.events
  'click .edit-event,
   click .edit-event-details': (event, instance) ->
    Modal.show 'editSmartEventDetailsModal',
      event: instance.data.smartEvent
