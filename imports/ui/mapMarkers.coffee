module.exports =
  getDefaultGradientColors: ->
    #gradient is made from shades of [red, green, blue]
    ['F07381', '345E7E', '72BC33']

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
      paths += '<path class="map-marker-path" fill="rgba(' + event.rgbColor + ', 0.8)" d="M' + radius + ',' + radius + ' L' + radius + ',0 A' + radius + ',' + radius + ' 1 ' + arcSweep + ',1 ' + x + ', ' + y + ' z" transform="rotate(' + rotation + ', ' + radius + ', ' + radius + ')" />'
      rotation += angle

    '<svg class="map-marker" width="' + size + '" height="' + size + '">' + paths + '<circle r="' + size * 0.12 + '" cx="' + size * 0.5 + '" cy="' + size * 0.5 + '" fill="rgb(245, 245, 243)" /></svg>'
