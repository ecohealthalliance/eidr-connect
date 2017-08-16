import UserEvents from '/imports/collections/userEvents.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import notify from '/imports/ui/notification'
import { buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'
import { formatLocations } from '/imports/utils'

Template.incidentList.onCreated ->
  @tableContentScrollable = @data.tableContentScrollable
  @accepted = @data.accepted
  @selectedIncidents = @data.selectedIncidents

  @scrollToAnnotation = (id) =>
    @data.selectedAnnotationId.set(id)
    $annotation = $("span[data-incident-id=#{id}]")
    $sourceTextContainer = $('.curator-source-details--copy')
    $sourceTextContainer.stop()
    $("span[data-incident-id]").removeClass('viewing')
    appHeaderHeight = $('header nav.navbar').outerHeight()
    detailsHeaderHeight = $('.curator-source-details--header').outerHeight()
    headerOffset = appHeaderHeight + detailsHeaderHeight
    containerScrollTop = $sourceTextContainer.scrollTop()
    annotationTopOffset = $annotation.offset().top
    countainerVerticalMidpoint = $sourceTextContainer.height() / 2
    totalOffset = annotationTopOffset - headerOffset
    # Distance of scroll based on postition of text container, scroll position
    # within the text container and the container's midpoint (to position the
    # annotation in the center of the container)
    scrollDistance =  totalOffset + containerScrollTop - countainerVerticalMidpoint
    $sourceTextContainer.animate
      scrollTop: scrollDistance
    , 500, -> $annotation.addClass('viewing')

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
  'click .view': (event, instance) ->
    event.stopPropagation()
    selectedAnnotationId = instance.data.selectedAnnotationId
    if selectedAnnotationId.get() is @_id
      selectedAnnotationId.set(null)
    else
      instance.scrollToAnnotation(@_id)

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
