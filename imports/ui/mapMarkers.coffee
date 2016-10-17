module.exports =
  getDefaultGradientColors: ->
    #gradient is made from shades of [red, yellow, blue]
    ["E30B0B","BFB10F", "1F87FF"]

  getMarkerHtml: (events, customSize) ->
    paths = ""
    rotation = 0
    size = if customSize then customSize else 20

    radius = size / 2

    angle = 360 * (1 / events.length)
    angleCalc = if events.length is 1 then 0.1 else if (angle > 180) then 360 - angle else angle
    angleRad = angleCalc * Math.PI / 180
    z = Math.sqrt(2 * radius * radius - (2 * radius * radius * Math.cos(angleRad)))

    if angleCalc <= 90
      x = radius * Math.sin(angleRad)
    else
      x = radius * Math.sin((180 - angleCalc) * Math.PI / 180)
    y = Math.sqrt(z * z - x * x)

    if angle <= 180
      x += radius
      arcSweep = 0
    else
      x = radius - x
      arcSweep = 1

    for event in events
      paths += '<path class="map-marker-path" fill="rgba(' + event.mapColorRGB + ', 0.7)" d="M' + radius + ',' + radius + ' L' + radius + ',0 A' + radius + ',' + radius + ' 1 ' + arcSweep + ',1 ' + x + ', ' + y + ' z" transform="rotate(' + rotation + ', ' + radius + ', ' + radius + ')" />'
      rotation += angle

    '<svg class="map-marker" width="' + size + '" height="' + size + '">' + paths + '<circle r="' + size * 0.12 + '" cx="' + size * 0.5 + '" cy="' + size * 0.5 + '" fill="rgb(245, 245, 243)" /></svg>'

  addEventToMarkers: (mapLocations, event, rgbColor) ->
    uniqueEventLocations = []
    for incident in event.incidents
      for location in incident.locations
        latLng = location.latitude.toString() + "," + location.longitude.toString()
        if latLng not in uniqueEventLocations
          if not mapLocations[latLng]
            mapLocations[latLng] = {name: location.name, events: []}
          mapLocations[latLng].events.push({id: event._id, eventName: event.eventName, incidents: event.incidents, mapColorRGB: rgbColor})
          uniqueEventLocations.push(latLng)

  addMarkersToMap: (map, instance, mapLocations) ->
    map.removeLayer instance.mapMarkers
    markers = instance.mapMarkers = new L.FeatureGroup()
    locationCount = 0
    for coordinates, loc of mapLocations
      locationCount++
      popupHtml = Blaze.toHTMLWithData(Template.markerPopup, {location: loc.name, events: loc.events})
      marker = L.marker(coordinates.split(","), {
        icon: L.divIcon({
          className: 'map-marker-container'
          iconSize:null
          html: @getMarkerHtml loc.events
        })
      }).bindPopup(popupHtml)
      markers.addLayer(marker)

    map.addLayer markers
    if locationCount
      map.fitBounds markers.getBounds(),
        maxZoom: 10
        padding: [20, 20]
