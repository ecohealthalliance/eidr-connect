MapHelpers = require '/imports/ui/mapMarkers.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'

L.Icon.Default.imagePath = "/packages/fuatsengul_leaflet/images"

Template.eventMap.onCreated ->
  @query = new ReactiveVar({})
  @pageNum = new ReactiveVar(0)
  @loading = new ReactiveVar(false)
  @eventsPerPage = 8
  @templateEvents = new ReactiveVar null
  @disablePrev = new ReactiveVar true
  @disableNext = new ReactiveVar false
  @selectedEvents = new Meteor.Collection null
  @subscribe('userEvents')

Template.eventMap.onRendered ->
  bounds = L.latLngBounds(L.latLng(-85, -180), L.latLng(85, 180))

  map = L.map('event-map', maxBounds: bounds).setView([10, -0], 3)
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png', {
    attribution: """Map tiles by <a href="http://cartodb.com/attributions#basemaps">CartoDB</a>, under <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>. Data by <a href="http://www.openstreetmap.org/">OpenStreetMap</a>, under ODbL.
    <br>
    CRS:
    <a href="http://wiki.openstreetmap.org/wiki/EPSG:3857" >
    EPSG:3857
    </a>,
    Projection: Spherical Mercator""",
    subdomains: 'abcd',
    type: 'osm'
    noWrap: true
    minZoom: 2
    maxZoom: 18
  }).addTo(map)

  @filteredMapLocations = {}
  @mapMarkers = new L.FeatureGroup()
  instance = @

  @autorun =>
    @query.get()
    @pageNum.set(0)

  @autorun =>
    query = @query.get()
    currentPage = @pageNum.get()
    eventsPerPage = @eventsPerPage

    if _.isObject query
      allEvents = UserEvents
        .find(query, {sort: {lastIncidentDate: -1}})
        .fetch()
        .filter (x)-> x.lastIncidentDate
      startingPosition = currentPage * eventsPerPage
      totalEventCount = allEvents.length
    else
      map.removeLayer instance.mapMarkers
      return

    filteredMapLocations = @filteredMapLocations = {}
    templateEvents = []
    eventIndex = startingPosition

    if totalEventCount
      colorScale = chroma.scale(
        MapHelpers.getDefaultGradientColors()).colors(eventsPerPage)
      if allEvents.length
        while templateEvents.length < eventsPerPage and eventIndex < allEvents.length
          event = allEvents[eventIndex]
          rgbColor = chroma(colorScale[templateEvents.length]).rgb()
          templateEvents.push
            _id: event._id
            eventName: event.eventName
            lastIncidentDate: event.lastIncidentDate
            rgbColor: rgbColor
            incidents: event.incidents
          eventIndex += 1
    @templateEvents.set templateEvents
    @disableNext.set if eventIndex < allEvents?.length then false else true
    @disablePrev.set if currentPage is 0 then true else false

  # Update the map markers to reflect user selection of events
  @autorun =>
    mapLocations = {}
    templateEvents = @templateEvents.get()

    # Create an array of the ids of the incidents of the selected events
    incidentIds = []
    @selectedEvents.find().fetch().forEach (event) ->
      incidentIds = _.union(incidentIds, _.pluck(event.incidents, 'id'))
    incidentIds

    @subscribe 'mapIncidents', incidentIds, =>
      @selectedEvents.find().forEach (selectedEvent) ->
        incidentIds = _.pluck selectedEvent.incidents, 'id'
        Incidents.find(_id: $in: incidentIds).map (incident) =>
          for location in incident.locations
            incident.userEventId = selectedEvent._id
            latLng = location.latitude + "," + location.longitude
            if not mapLocations[latLng]
              mapLocations[latLng] =
                name: location.name
                incidents: []
                events: []
            mapLocations[latLng].events = _.union(
              mapLocations[latLng].events, [selectedEvent._id])
            mapLocations[latLng].incidents = _.union(
              mapLocations[latLng].incidents, [incident])

      map.removeLayer(@mapMarkers)
      markers = @mapMarkers = new L.FeatureGroup()
      for coordinates, location of mapLocations
        locationEvents = templateEvents.filter (e)->
          e._id in location.events
        popupHtml = Blaze.toHTMLWithData Template.markerPopup,
          name: location.name
          locationEvents: locationEvents.map (event)->
            eventCopy = _.clone(event)
            eventCopy.mostRecentIncident = _.chain(location.incidents)
              .filter (i)-> i.userEventId == event._id
              .sortBy (i)-> i.dateRange.start
              .value()[0]
            eventCopy

        marker = L.marker(coordinates.split(","),
          icon: L.divIcon
            className: 'map-marker-container'
            iconSize: null
            html: MapHelpers.getMarkerHtml(locationEvents)
        ).bindPopup(popupHtml, closeButton: false)
        markers.addLayer(marker)
      map.addLayer(markers)

      if _.isEmpty(mapLocations)
        map.setView([10, -0], 3)
      else
        map.fitBounds markers.getBounds(),
          maxZoom: 10
          padding: [20, 20]

      @loading.set(false)


Template.eventMap.helpers
  getQuery: ->
    Template.instance().query

  templateEvents: ->
    Template.instance().templateEvents

  disablePrev: ->
    Template.instance().disablePrev

  disableNext: ->
    Template.instance().disableNext

  query: ->
    Template.instance().query

  selectedEvents: ->
    Template.instance().selectedEvents

  incidentsLoaded: ->
    not Template.instance().loading.get()

  incidentsLoading: ->
    Template.instance().loading

paginate = (template, direction) ->
  template.pageNum.set template.pageNum.get() + direction
  template.selectedEvents.remove {}

Template.eventMap.events
  "click .event-list-next:not('.disabled')": (event, template) ->
    paginate template, 1
  "click .event-list-prev:not('.disabled')": (event, template) ->
    paginate template, -1
