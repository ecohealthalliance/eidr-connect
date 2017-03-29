UserEvents = require '/imports/collections/userEvents.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
{ notify } = require '/imports/ui/notification'
SCROLL_WAIT_TIME = 250

_acceptedQuery = (accepted) ->
  query = {}
  if accepted
    query.accepted = true
  else if not _.isUndefined(accepted) and not accepted
    query.accepted = {$ne: true}
  query

_updateAllIncidentsStatus = (instance, select, event) ->
  selectedIncidents = instance.selectedIncidents
  query = _acceptedQuery(instance.accepted)
  if select
    Incidents.find(query).forEach (incident) ->
      id = incident._id
      selectedIncidents.upsert id: id,
        id: id
        accepted: incident.accepted
  else
    selectedIncidents.remove(query)
  event.currentTarget.blur()

_selectedIncidents = (instance) ->
  query = _acceptedQuery(instance.accepted)
  instance.selectedIncidents.find(query)

_incidentsSelected = (instance) ->
  _selectedIncidents(instance).count()

Template.incidentTable.onCreated ->
  @selectedIncidents = new Meteor.Collection(null)
  @addingEvent = new ReactiveVar(false)
  @selectedEventId = new ReactiveVar(false)
  @tableContentScrollable = @data.tableContentScrollable
  @accepted = @data.accepted
  @scrollToAnnotation = (id) =>
    intervalTime = 0
    @interval = setInterval =>
      if intervalTime >= SCROLL_WAIT_TIME
        @stopScrollingInterval()
        $annotation = $("span[data-incident-id=#{id}]")
        $sourceTextContainer = $('.curator-source-details--copy')
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
        $sourceTextContainer.stop().animate
          scrollTop: scrollDistance
        , 500, -> $annotation.addClass('viewing')
      intervalTime += 100
    , 100

  @stopScrollingInterval = ->
    clearInterval(@interval)

Template.incidentTable.onRendered ->
  @autorun =>
    if not _incidentsSelected(@)
      @addingEvent.set(false)
      @selectedEventId.set(null)

Template.incidentTable.helpers
  incidents: ->
    instance = Template.instance()
    query = _acceptedQuery(instance.accepted)
    query.url = {$regex: new RegExp("#{instance.data.source._sourceId}$")}
    Incidents.find(query)

  allSelected: ->
    instance = Template.instance()
    selectedIncidentCount = _incidentsSelected(instance)
    query = _acceptedQuery(instance.accepted)
    Incidents.find(query).count() == selectedIncidentCount

  selected: ->
    Template.instance().selectedIncidents.findOne(id: @_id)

  incidentsSelected: ->
    _incidentsSelected(Template.instance())

  acceptance: ->
    not Template.instance().accepted

  action: ->
    if Template.instance().accepted
      'Reject'
    else
      'Accept'

  addEvent: ->
    Template.instance().addingEvent.get()

  selectedIncidents: ->
    _selectedIncidents(Template.instance())

  tableContentScrollable: ->
    Template.instance().tableContentScrollable

  tableType: ->
    if Template.instance().accepted
      'accepted'
    else
      'rejected'

Template.incidentTable.events
  'click .incident-table tbody tr': (event, instance) ->
    event.stopPropagation()
    selectedIncidents = instance.selectedIncidents
    query = id: @_id
    if selectedIncidents.findOne(query)
      selectedIncidents.remove(query)
    else
      query.accepted = @accepted
      selectedIncidents.insert(query)

  'click table.incident-table tr td.edit': (event, instance) ->
    event.stopPropagation()
    Modal.show 'incidentModal',
      articles: [instance.data.source]
      userEventId: null
      edit: true
      incident: @
      updateEvent: false

  'click .action': (event, instance) ->
    accepted = instance.accepted
    accept = true
    if accepted
      accept = false
    selectedIncidents = instance.selectedIncidents
    selectedIncidents.find(_acceptedQuery(accepted)).forEach (incident) ->
      incident = _id: incident.id
      incident.accepted = accept
      Meteor.call 'updateIncidentReport', incident, (error, result) ->
        if error
          notify('error', 'There was a problem updating your incident reports.')
          return
    selectedIncidents.remove({})
    event.currentTarget.blur()

  'click .select-all': (event, instance) ->
    _updateAllIncidentsStatus(instance, true, event)

  'click .deselect-all': (event, instance) ->
    _updateAllIncidentsStatus(instance, false, event)

  'mouseover .incident-table tbody tr': (event, instance) ->
    if not instance.data.scrollToAnnotations or not @annotations?.case?[0].textOffsets
      return
    instance.scrollToAnnotation(@_id)

  'mouseout .incident-table tbody tr': (event, instance) ->
    if not instance.data.scrollToAnnotations or not @annotations?.case?[0].textOffsets
      return
    instance.stopScrollingInterval()

  'click .show-addEvent': (event, instance) ->
    addingEvent = instance.addingEvent
    addingEvent.set(not addingEvent.get())
    event.currentTarget.blur()
