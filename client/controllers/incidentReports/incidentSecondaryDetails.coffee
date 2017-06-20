import { formatLocation } from '/imports/utils'

Template.incidentSecondaryDetails.onCreated ->
  @detailsOpen = new ReactiveVar(false)
  Meteor.defer =>
    @$('[data-toggle=tooltip]').tooltip delay: show: '400'

Template.incidentSecondaryDetails.helpers
  detailsOpen: ->
    Template.instance().detailsOpen.get()

  firstLocationName: ->
    firstLocation = Template.instance().data.locations[0]
    firstLocation?.countryName or firstLocation?.name

  hasAdditionalInfo: ->
    @locations.length > 1 or formatLocation(@locations[0]).split(',').length > 1

  associatedEventCount: ->
    Template.instance().data.incidentEvents.length

Template.incidentSecondaryDetails.events
  'click .toggle-details': (event, instance) ->
    event.stopPropagation()
    detailsOpen = instance.detailsOpen
    detailsOpen.set(not detailsOpen.get())

  'click .disassociate-event': (event, instance) ->
    event.stopPropagation()
    instanceData = instance.data
    Meteor.call 'removeIncidentFromEvent', instanceData.incidentId, @_id, (error, res) ->
      $('.tooltip').remove()
