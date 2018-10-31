import EventIncidents from '/imports/collections/eventIncidents'
import { formatLocation } from '/imports/utils'
import MapHelpers from '/imports/ui/mapMarkers.coffee'
import Constants from '/imports/constants'
{
  LocationTree,
  convertAllIncidentsToDifferentials
  differentialIncidentsToSubIntervals,
  extendSubIntervalsWithValues,
  createSupplementalIncidents
} = require('incident-resolution')

Template.eventAffectedAreas.onCreated ->
  @maxCount = new ReactiveVar()
  @choroplethLayer = new ReactiveVar('cases')
  @markerLayer = new ReactiveVar()
  @worldGeoJSONRV = new ReactiveVar()
  @loading = new ReactiveVar(false)
  @tooManyIncidents = new ReactiveVar(false)
  HTTP.get '/world.geo.json', (error, resp) =>
    if error
      console.error error
      return
    @worldGeoJSONRV.set(resp.data)

Template.eventAffectedAreas.onRendered ->
  @$('[data-toggle=tooltip]').tooltip
    placement: 'bottom'
    delay: 300

  bounds = L.latLngBounds(L.latLng(-85, -180), L.latLng(85, 180))
  leMap = L.map('map', maxBounds: bounds).setView([10, -0], 3)
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
    attribution: """Map tiles by <a href="http://cartodb.com/attributions#basemaps">CartoDB</a>,
    under <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>.
    Data by <a href="http://www.openstreetmap.org/">OpenStreetMap</a>, under ODbL.
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
  ).addTo(leMap)

  geoJsonLayer = null

  ramp = chroma.scale(["#345e7e", "#f07381"]).colors(10)

  @getColor = (val) ->
    # return a color from the ramp based on a 0 to 1 value.
    # If the value exceeds one the last stop is used.
    ramp[Math.floor(ramp.length * Math.max(0, Math.min(val, 0.99)))]

  zoomToFeature = (event) =>
    leMap.fitBounds(event.target.getBounds())

  highlightFeature = (event) =>
    layer = event.target
    layer.setStyle
      weight: 1
      fillColor: '#2CBA74'
      color: '#2CBA74'
      dashArray: ''
      fillOpacity: 0.75
    if not L.Browser.ie and not L.Browser.opera
      layer.bringToFront()

  resetHighlight = (event) =>
    geoJsonLayer.resetStyle(event.target)

  updateGeoJSONLayer = (worldGeoJSON, incidentType, incidents) =>
    if geoJsonLayer
      leMap.removeLayer(geoJsonLayer)
    mapableIncidents = incidents.fetch().filter (i) ->
      i.locations.every (l) -> l.featureCode
    if incidentType and worldGeoJSON
      baseIncidents = []
      constrainingIncidents = []
      mapableIncidents.map (incident) ->
        if incident.constraining
          constrainingIncidents.push incident
        else
          baseIncidents.push incident
      supplementalIncidents = createSupplementalIncidents(baseIncidents, constrainingIncidents)
      differentialIncidents = convertAllIncidentsToDifferentials(
        baseIncidents
      ).concat(supplementalIncidents)
      differentialIncidents = _.where(
        differentialIncidents, type: incidentType
      )
      subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
      if subIntervals.length > Constants.MAX_SUBINTERVALS
        @tooManyIncidents.set(true)
        @maxCount.set(0)
        return
      else
        @tooManyIncidents.set(false)
      extendSubIntervalsWithValues(differentialIncidents, subIntervals)
      for subInterval in subIntervals
        subInterval.incidents = subInterval.incidentIds.map (id) ->
          differentialIncidents[id]
      subIntervals = subIntervals.filter (subI) ->
        # Filter out sub-intervals that don't have country level resolution or better.
        subI.locationId != "6295630"
      locationTree = LocationTree.from(subIntervals.map (x) -> x.location)
      topLocations = locationTree.children.map (x) -> x.value
      locToSubintervals = {}
      for topLocation in topLocations
        locToSubintervals[topLocation.id] = []
      for topLocation in topLocations
        for subInterval in subIntervals
          loc = subInterval.location
          if LocationTree.locationContains(topLocation, loc)
            locToSubintervals[topLocation.id].push(subInterval)
      countryCodeToCount = {}
      _.pairs(locToSubintervals).map ([key, locSubIntervals]) ->
        location = locationTree.getLocationById(key)
        groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
        maxSubintervals = []
        for group, subIntervalGroup of groupedLocSubIntervals
          maxSubintervals.push(_.max(subIntervalGroup, (x) -> x.value))
        maxSubintervals = _.sortBy(maxSubintervals, (x) -> x.start)
        total = 0
        formattedData = maxSubintervals.forEach (subInt) ->
          rate = subInt.value / ((subInt.end - subInt.start) / 1000 / 60 / 60 / 24)
          total += subInt.value
        prevTotal = countryCodeToCount[location.countryCode] or 0
        countryCodeToCount[location.countryCode] = prevTotal + total
      maxCount = _.max(_.values(countryCodeToCount))
      @maxCount.set maxCount
      geoJsonLayer = L.geoJson(
        features: worldGeoJSON.features
        type: "FeatureCollection"
      ,
        style: (feature) =>
          count = countryCodeToCount[feature.properties.iso_a2]
          fillColor = @getColor(count / maxCount)
          opacity = 0.75
          unless fillColor
            opacity = 0
          fillColor: fillColor
          weight: 1
          opacity: 1
          color: '#DDDDDD'
          dashArray: '3'
          fillOpacity: opacity
        onEachFeature: (feature, layer) ->
          layer.on
            mouseover: highlightFeature
            mouseout: resetHighlight
            click: zoomToFeature
      ).addTo(leMap)

  @autorun =>
    worldGeoJSON = @worldGeoJSONRV.get()
    incidentType = @choroplethLayer.get()
    incidents = EventIncidents.find(@data.filterQuery.get())
    @loading.set(true)
    # Allow UI to update (loading indicator and clicked nav item)
    # before updating map
    setTimeout =>
      updateGeoJSONLayer(worldGeoJSON, incidentType, incidents)
      @loading.set(false)
    , 200

  markerLayerGroup = null
  @autorun =>
    if markerLayerGroup
      leMap.removeLayer(markerLayerGroup)
    incidentsByLatLng = {}
    EventIncidents.find(@data.filterQuery.get()).map (incident) ->
      incident.locations.forEach (location) ->
        key = "#{location.latitude},#{location.longitude}"
        incidentsByLatLng[key] = (incidentsByLatLng[key] or []).concat(incident)
    for key, incidents of incidentsByLatLng
      incidentsByLatLng[key] = _.uniq(incidents, false, (x) -> x._id)
    if @markerLayer.get()
      markerLayerGroup = L.layerGroup()
      for key, incidents of incidentsByLatLng
        L.marker(key.split(',').map(parseFloat),
          icon: L.divIcon
            className: 'map-marker-container'
            iconSize: null
            html: MapHelpers.getMarkerHtml([ rgbColor: [ 244, 143, 103 ] ])
        ).bindPopup(Blaze.toHTMLWithData(
          Template.affectedAreasMarkerPopup,
          incidents: incidents
        ), closeButton: false)
        .addTo(markerLayerGroup)
      markerLayerGroup.addTo(leMap)

  @autorun =>
    # Update selected tab based on type filters
    selectedIncidentTypes = @data.selectedIncidentTypes.get()
    if 'cases' in selectedIncidentTypes and 'deaths' not in selectedIncidentTypes
      @choroplethLayer.set('cases')
    else if 'cases' not in selectedIncidentTypes and 'deaths' in selectedIncidentTypes
      @choroplethLayer.set('deaths')

Template.eventAffectedAreas.helpers
  tooManyIncidents: ->
    Template.instance().tooManyIncidents.get()

  legendValues: ->
    maxCount = Template.instance().maxCount.get()
    _.range(1, 1 + (maxCount or 0), maxCount / 5).map (value) ->
      value: value.toFixed(0)
      color: Template.instance().getColor(value / maxCount)

  choroplethLayerIs: (name) ->
    choroplethLayer = Template.instance().choroplethLayer.get()
    if (not choroplethLayer and name == '') or choroplethLayer == name
      'active'

  markerLayerIs: (name) ->
    markerLayer = Template.instance().markerLayer.get()
    if (not markerLayer and name == '') or markerLayer == name
      'active'

  isLoading: ->
    Template.instance().loading.get()

  disableCases: ->
    'cases' not in Template.instance().data.selectedIncidentTypes.get()

  disableDeaths: ->
    'deaths' not in Template.instance().data.selectedIncidentTypes.get()

Template.eventAffectedAreas.events
  'click .cases-layer a': (event, instance) ->
    $('.tooltip').remove()
    instance.choroplethLayer.set('cases')

  'click .deaths-layer a': (event, instance) ->
    $('.tooltip').remove()
    instance.choroplethLayer.set('deaths')

  'click .choropleth-layer-off a': (event, instance) ->
    instance.maxCount.set(null)
    instance.choroplethLayer.set(null)

  'click .marker-layer a': (event, instance) ->
    instance.markerLayer.set('incidentLocations')

  'click .marker-layer-off a': (event, instance) ->
    instance.markerLayer.set(null)

  'click .view-incident': (event, instance) ->
    incidentId = $(event.currentTarget).data('id')
    if incidentId
      Modal.show 'incidentModal',
        incident: EventIncidents.findOne(incidentId)
