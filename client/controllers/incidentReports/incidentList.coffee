import UserEvents from '/imports/collections/userEvents.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import { notify } from '/imports/ui/notification'
import { buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'
import {
  formatLocation,
  formatLocations } from '/imports/utils'

Template.incidentList.onCreated ->
  @tableContentScrollable = @data.tableContentScrollable
  @accepted = @data.accepted
  @selectedIncidents = @data.selectedIncidents

  @acceptedQuery = =>
    query = {}
    if @accepted
      query.accepted = true
    else if not _.isUndefined(@accepted) and not @accepted
      query.accepted = {$ne: true}
    query

  @getSelectedIncidents = =>
    query = @acceptedQuery()
    @data.selectedIncidents.find(query)

  @incidentsSelectedCount = =>
    @getSelectedIncidents().count()

Template.incidentList.onRendered ->
  Meteor.defer =>
    @$('[data-toggle="tooltip"]').tooltip()

  @autorun =>
    @selectedIncidents.find().forEach (incident) =>
      query =
        _id: incident.id
        accepted: true
      unless Incidents.findOne(query)
        @selectedIncidents.remove(id: query._id)

Template.incidentList.helpers
  incidents: ->
    instance = Template.instance()
    query =
      articleId: instance.data.source._id
      accepted: true
    _.sortBy Incidents.find(query).fetch(), (incident) ->
      incident.annotations?.case?[0].textOffsets?[0]

  tableType: ->
    if Template.instance().accepted
      'accepted'
    else
      'rejected'

  annotationSelected: ->
    Template.instance().data.selectedAnnotationId.get() is @_id

  otherLocations: ->
    return if @locations.length <= 1
    otherLocations = @locations.slice()
    otherLocations?.shift()
    if otherLocations?.length
      formatLocations(otherLocations)

  incidentEvents: ->
    if @_id
      UserEvents.find('incidents.id': @_id).fetch()

  selected: ->
    Template.instance().selectedIncidents.findOne(id: @_id)

Template.incidentList.events
  'click .incident': (event, instance) ->
    event.stopPropagation()
    selectedIncidents = instance.data.selectedIncidents
    query = id: @_id
    if selectedIncidents.findOne(query)
      selectedIncidents.remove(query)
    else
      selectedIncidents.insert(query)

  'click .incident .edit': (event, instance) ->
    event.stopPropagation()
    source = instance.data.source
    snippetHtml = buildAnnotatedIncidentSnippet(source.enhancements.source.cleanContent.content, @, false)
    Modal.show 'suggestedIncidentModal',
      incident: @
      incidentText: Spacebars.SafeString(snippetHtml)
      articleId: source._id
      userEventId: null
      offCanvasStartPosition: 'top'
      showBackdrop: true

Template.incidentSecondaryDetails.onCreated ->
  @detailsOpen = new ReactiveVar(false)
  Meteor.defer =>
    @$('[data-toggle=tooltip]').tooltip delay: show: '400'

Template.incidentSecondaryDetails.helpers
  detailsOpen: ->
    Template.instance().detailsOpen.get()

  firstLocationName: ->
    firstLocation = Template.instance().data.locations[0]
    firstLocation?.countryName or
      firstLocation?.admin1Name or
      firstLocation?.admin2Name or
      firstLocation?.name

  hasAdditionalInfo: ->
    @locations.length > 1 or formatLocation(@locations[0]).split(',').length > 1

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
