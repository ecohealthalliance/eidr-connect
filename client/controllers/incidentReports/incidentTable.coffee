Incidents = require '/imports/collections/incidentReports.coffee'
{ notify } = require '/imports/ui/notification'

SCROLL_WAIT_TIME = 500

updateAllIncidentsStatus = (instance, status, event) ->
  selectedIncidents = instance.selectedIncidents
  if status
    Incidents.find().forEach (incident) ->
      selectedIncidents.insert
        id: incident._id
  else
    selectedIncidents.remove({})
  event.currentTarget.blur()

Template.incidentTable.onCreated ->
  @selectedIncidents = new Meteor.Collection(null)
  @scrollToAnnotation = (id) =>
    intervalTime = 0
    @interval = setInterval =>
      if intervalTime >= SCROLL_WAIT_TIME
        @stopScrollingInterval()
        $annotation = $("span[data-incident-id=#{id}]")
        $sourceTextContainer = $('.curator-source-details--copy')
        if window.innerWidth >= 1500 # In side-by-side view
          $sourceTextContainer = $('.curator-source-details--copy-wrapper')
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

Template.incidentTable.helpers
  incidents: ->
    Incidents.find({accepted: {$ne: false}})

  incidentsSelected: ->
    Template.instance().selectedIncidents.find().count() > 0

  allSelected: ->
    selectedIncidentCount = Template.instance().selectedIncidents.find().count()
    Incidents.find().count() == selectedIncidentCount

  selected: ->
    Template.instance().selectedIncidents.findOne(id: @_id)

Template.incidentTable.events
  'click table.incident-table tr td .select': (event, instance) ->
    event.stopPropagation()
    selectedIncidents = instance.selectedIncidents
    query = id: @_id
    if selectedIncidents.findOne(query)
      selectedIncidents.remove(query)
    else
      selectedIncidents.insert(query)

  'click .reject': (event, instance) ->
    selectedIncidents = instance.selectedIncidents
    selectedIncidents.find().forEach (incident) ->
      incident = _id: incident.id
      incident.accepted = status
      Meteor.call 'updateIncidentReport', incident, false, (error, result) ->
        if error
          notify('error', 'There was a problem updating your incident reports.')
          return
    selectedIncidents.remove({})
    event.currentTarget.blur()

  'click .select-all': (event, instance) ->
    updateAllIncidentsStatus(instance, true, event)

  'click .deselect-all': (event, instance) ->
    updateAllIncidentsStatus(instance, false, event)

  'mouseover .incident-table tbody tr': (event, instance) ->
    if not instance.data.scrollToAnnotations
      return
    instance.scrollToAnnotation(@_id)

  'mouseout .incident-table tbody tr': (event, instance) ->
    if not instance.data.scrollToAnnotations
      return
    instance.stopScrollingInterval()
