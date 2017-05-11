MapHelpers = require '/imports/ui/mapMarkers.coffee'

Template.map.rendered = ->
  eventMap = L.map 'map',
    scrollWheelZoom: false,
    maxBounds: L.latLngBounds(L.latLng(-85, -180), L.latLng(85, 180))
  eventMap.on 'click', ->
    eventMap.scrollWheelZoom.enable()
  eventMap.on 'mouseout', ->
    eventMap.scrollWheelZoom.disable()

  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
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
    minZoom: 1
    maxZoom: 18
  ).addTo(eventMap)
  markers = []

  @autorun ->
    templateData = Template.currentData()
    eventData = templateData.event
    locations = templateData.incidentLocations

    for marker in markers
      eventMap.removeLayer marker
    markers = []
    eventData.rgbColor = '240, 115, 130'
    if locations
      latLngs = ([location.latitude, location.longitude] for location in locations)
      latLngs = _.filter latLngs, (latLng) ->
        latLng[0] isnt 'Not Found' and latLng[1] isnt 'Not Found'
      if latLngs.length is 1
        eventMap.setView(latLngs[0], 4)
      else
        eventMap.fitBounds(latLngs, {padding: [15,15]})
      for location in locations
        latLng = [location.latitude, location.longitude]
        if latLng[0] isnt 'Not Found' and latLng[1] isnt 'Not Found'
          popupHtml = Blaze.toHTMLWithData Template.markerPopupMinimal,
            location: location.name
            addedDate: location.addedDate

          circle = L.marker latLng,
            icon: L.divIcon
              className: 'map-marker-container'
              iconSize:null
              html: MapHelpers.getMarkerHtml([eventData])
          .bindPopup(popupHtml, {closeButton: false, className: 'minimal-popup'})
          .addTo(eventMap)

          markers.push circle
