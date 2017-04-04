Incidents = require '/imports/collections/incidentReports.coffee'

findIncident = (accepted) ->
  query = {}
  query.url = $regex: new RegExp("#{Template.instance().data.source._sourceId}$")
  if accepted
    query.accepted = $eq: true
  else if not _.isUndefined(accepted)
    query.accepted = $ne: true
  Incidents.findOne(query)

Template.sourceIncidentReports.onCreated ->
  @tableContentScrollable = new ReactiveVar(true)

  @autorun =>
    selectedAnnotationId = @data.selectedAnnotationId.get()
    return if not selectedAnnotationId
    $tableContainer = @$('.curator-source-details--incidents-container')
    return if $tableContainer[0].scrollHeight <= $tableContainer[0].clientHeight
    $selectedIncidentRow = $("tr[data-incident-id=#{selectedAnnotationId}]")
    # Sum of heights of elements affecting scroll distance
    headerHeight = (
      $('.curator-source-details--main-header').outerHeight() +
      $('.curator-source-details--header').outerHeight()
    )
    rowTop = $selectedIncidentRow.position().top
    # Acutal distance of scroll - Element's top position relative to parent
    # container (.curator-source-details) minus the header heights and
    # with the table container's top scroll distance.
    scrollDistance = rowTop - headerHeight + $tableContainer.scrollTop()
    $tableContainer.animate(scrollTop: scrollDistance, 500)

Template.sourceIncidentReports.helpers
  tableContentScrollable: ->
    Template.instance().tableContentScrollable

  tableContentIsScrollable: ->
    Template.instance().tableContentScrollable.get()

  hasAcceptedIncidents: ->
    findIncident(true)

  hasRejectedIncidents: ->
    findIncident(false)

  hasIncidents: ->
    findIncident()
