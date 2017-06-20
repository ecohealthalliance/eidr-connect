Template.coordinateSelector.onCreated ->
  @latLon = @data.value or new ReactiveVar()
  @required = @data.required

Template.coordinateSelector.onRendered ->
  @marker = null
  @clearMarker = =>
    if @marker then @map.removeLayer(@marker)

  L.Icon.Default.imagePath = '/packages/fuatsengul_leaflet/images'
  @map = L.map('leaflet-canvas',
    #scrollWheelZoom: true
    maxBounds: L.latLngBounds(L.latLng(-85, -180), L.latLng(85, 180))
  ).setView([0, 0], 2)
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
    attribution: """Map tiles by <a href="http://cartodb.com/attributions#basemaps">CartoDB</a>, under <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>. Data by <a href="http://www.openstreetmap.org/">OpenStreetMap</a>, under ODbL.
    <br>
    CRS:
    <a href="http://wiki.openstreetmap.org/wiki/EPSG:3857" >
    EPSG:3857
    </a>,
    Projection: Spherical Mercator""",
    subdomains: 'abcd'
    type: 'osm'
    noWrap: true
    minZoom: 1
    maxZoom: 18
  ).addTo(@map)

  @map.on 'click', (e) =>
    @latLon.set([e.latlng.lat, e.latlng.lng])

  @autorun =>
    latLon = @latLon.get()
    @clearMarker()
    if latLon
      location = new L.LatLng(latLon[0], latLon[1])
      @marker = L.marker(location).addTo(@map)

  Meteor.setTimeout =>
    # The initial size is wrong causing some of the tiles not to load.
    @map.invalidateSize()
  , 500

Template.coordinateSelector.helpers
  latitude: ->
    Template.instance().latLon.get()?[0]
  longitude: ->
    Template.instance().latLon.get()?[1]
  required: ->
    Template.instance().required

Template.coordinateSelector.events
  'click .leaflet-clear': (event, t) ->
    event.preventDefault()
    t.latLon.set(null)

  'change .lat, change .lon': (event, t) ->
    lon = parseFloat(t.$('.lon').val())
    lat = parseFloat(t.$('.lat').val())
    if not isNaN(lon) and not isNaN(lat)
      t.latLon.set([lat, lon])
