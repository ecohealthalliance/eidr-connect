import EventIncidents from '/imports/collections/eventIncidents'
import { formatLocation } from '/imports/utils'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials.coffee'
import {
  differentailIncidentsToSubIntervals,
  extendSubIntervalsWithValues
} from '/imports/incidentResolution/incidentResolution.coffee'
import LocationTree from '/imports/incidentResolution/LocationTree.coffee'

Template.eventAffectedAreas.onCreated ->
  @choroplethLayer = new ReactiveVar()
  @markerLayer = new ReactiveVar()
  @worldGeoJSONRV = new ReactiveVar()
  @loading = new ReactiveVar(false)
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

  ramp = chroma.scale(["#345e7e", "#f07381"]).colors(10)

  getColor = (val) ->
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

  clearMap = =>
    if @geoJsonLayer
      leMap.removeLayer(@geoJsonLayer)

  updateMap = (worldGeoJSON, incidentType, incidents) =>
    clearMap()
    mapableIncidents = incidents.fetch().filter (i) ->
      i.locations.every (l) -> l.featureCode
    if incidentType and worldGeoJSON
      differentials = convertAllIncidentsToDifferentials(mapableIncidents)
      differentials = _.where(differentials, type: incidentType)
      subIntervals = differentailIncidentsToSubIntervals(differentials)
      extendSubIntervalsWithValues(differentials, subIntervals)
      for subInterval in subIntervals
        subInterval.incidents = subInterval.incidentIds.map (id) ->
          differentials[id]

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
      @geoJsonLayer = L.geoJson(
        features: worldGeoJSON.features
        type: "FeatureCollection"
      ,
        style: (feature) =>
          count = countryCodeToCount[feature.properties.iso_a2]
          fillColor = getColor(count / maxCount)
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

  resetHighlight = (event) =>
    @geoJsonLayer.resetStyle(event.target)

  @autorun =>
    worldGeoJSON = @worldGeoJSONRV.get()
    incidentType = @choroplethLayer.get()
    incidents = EventIncidents.find(@data.filterQuery.get())
    if incidentType
      @loading.set(true)
      # Allow UI to update (loading indicator and clicked nav item)
      # before updating map
      setTimeout =>
        updateMap(worldGeoJSON, incidentType, incidents)
        @loading.set(false)
      , 200
    else
      clearMap()

    @autorun =>
      # Update selected tab based on type filters
      selectedIncidentTypes = @data.selectedIncidentTypes.get()
      if 'cases' in selectedIncidentTypes and 'deaths' not in selectedIncidentTypes
        @choroplethLayer.set('cases')
      else if 'cases' not in selectedIncidentTypes and 'deaths' in selectedIncidentTypes
        @choroplethLayer.set('deaths')

Template.eventAffectedAreas.helpers
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
    instance.choroplethLayer.set(null)

  'click .marker-layer a': (event, instance) ->
    instance.markerLayer.set('incidentLocations')

  'click .marker-layer-off a': (event, instance) ->
    instance.markerLayer.set(null)
