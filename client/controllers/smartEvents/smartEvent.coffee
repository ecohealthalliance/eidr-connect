SmartEvents = require '/imports/collections/smartEvents'
Incidents = require '/imports/collections/incidentReports'
#Allow multiple modals or the suggested locations list won't show after the
#loading modal is hidden
Modal.allowMultiple = true

Template.smartEvent.onCreated ->
  @editState = new ReactiveVar(false)
  @eventId = new ReactiveVar()
  @loading = new ReactiveVar(true)

Template.smartEvent.onRendered ->
  eventId = Router.current().getParams()._id
  @eventId.set(eventId)
  @subscribe 'smartEvents', eventId
  @autorun =>
    event = SmartEvents.findOne(eventId)
    if event
      eventDateRange = event.dateRange
      locations = event.locations
      query = {}
      if event.diseases and event.diseases.length > 0
        query['resolvedDisease.id'] = $in: event.diseases.map (x)-> x.id
      if eventDateRange
        query['dateRange.start'] = $lte: eventDateRange.end
        query['dateRange.end'] = $gte: eventDateRange.start
      locationQueries = []
      for location in locations
        locationQueries.push
          id: location.id
        locationQuery =
          countryName: location.countryName
        featureCode = location.featureCode
        if featureCode.startsWith("PCL")
          locationQueries.push(locationQuery)
        else
          locationQuery.admin1Name = location.admin1Name
          if featureCode is 'ADM1'
            locationQueries.push(locationQuery)
          else
            locationQuery.admin2Name = location.admin2Name
            if featureCode is 'ADM2'
              locationQueries.push(locationQuery)
      locationQueries = _.chain(locationQueries).compact().map((x)->
        result = {}
        for prop, value of x
          result['locations.'+prop] = value
        return result
      ).value()
      if locationQueries.length > 0
        query['$or'] = locationQueries
      @subscribe 'smartEventIncidents', query,
        onReady: =>
          @loading.set(false)

Template.smartEvent.onRendered ->
  new Clipboard '.copy-link'

Template.smartEvent.helpers
  smartEvent: ->
    SmartEvents.findOne(Template.instance().eventId.get())

  isEditing: ->
    Template.instance().editState.get()

  deleted: ->
    SmartEvents.findOne(Template.instance().eventId.get())?.deleted

  incidentReportsTemplateData: ->
    incidents: Incidents.find({}, sort: 'dateRange.end': 1)
    eventType: 'smart'

  isLoading: ->
    Template.instance().loading.get()

Template.smartEvent.events
  'click .edit-link, click #cancel-edit': (event, instance) ->
    instance.editState.set(not instance.editState.get())
