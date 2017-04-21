import d3 from 'd3'

MINIMUM_ZOOM_THRESHOLD = 5 # move at least 5x5 pixels to zoom

class Zoom
  ###
  # Zoom - a zoomable interface for a plot
  #
  # @param {object} plot, the plot to enable the zooming interface
  # @param {object} options, the object containing the passed in options to the plot constructor
  # @return {object} this
  ###
  constructor: (plot, options) ->
    @plot = plot
    @options = options

    @bandPos = [-1, -1];
    @zoomArea =
      x1: 0
      y1: 0
      x2: 0
      y2: 0
    @drag = d3.drag();
    @zoomGroup = plot.container.append('g').attr('class', 'scatterPlot-zoom')
    @zoomBand = @zoomGroup.append('rect')
      .attr('width', 0)
      .attr('height', 0)
      .attr('x', 0)
      .attr('y', 0)
      .attr('class', 'zoomBand')
    @zoomOverlay = @zoomGroup.append('rect')
      .attr('width', plot.getWidth())
      .attr('height', plot.getHeight())
      .attr('transform', "translate(#{plot.margins.left}, 0)")
      .attr('class', 'zoomOverlay')
      .call(@drag);

    self = @
    @drag.on 'start.plot', () ->
      pos = d3.mouse(@)
      self.dragStart = pos

    @drag.on 'drag.plot', () ->
      # Note: @ (this) is not the Zoom class but the DOM event
      pos = d3.mouse(@)
      _.bind(self.ondrag, self)(pos)

    @drag.on 'end.plot', () ->
      # Note: @ (this) is not the Zoom class but the DOM event
      pos = d3.mouse(@)

      zoomX = false
      if Math.abs(self.dragStart[0] - pos[0]) > MINIMUM_ZOOM_THRESHOLD
        zoomX = true

      zoomY = false
      if Math.abs(self.dragStart[1] - pos[1]) > MINIMUM_ZOOM_THRESHOLD
        zoomY = true

      _.bind(self.ondragend, self)(pos, zoomX && zoomY)

  ###
  # ondrag - the event handler for the ondrag event
  #
  # @param {array} pos, the x,y position of the mouse
  ###
  ondrag: (pos) ->
    if pos[0] < @bandPos[0]
      @zoomBand.attr('transform', "translate(#{(pos[0] + @plot.margins.left)}, #{@bandPos[1]})")
    if pos[1] < @bandPos[1]
      @zoomBand.attr('transform', "translate(#{(pos[0] + @plot.margins.left)}, #{pos[1]})")
    if pos[1] < @bandPos[1] and pos[0] > @bandPos[0]
      @zoomBand.attr('transform', "translate(#{(@bandPos[0] + @plot.margins.left)}, #{pos[1]})")
    if @bandPos[0] == -1
      @bandPos = pos;
      @zoomBand.attr('transform', "translate(#{(@bandPos[0] + @plot.margins.left)}, #{@bandPos[1]})")
    @zoomBand.transition().duration(1)
      .attr('width', Math.abs(@bandPos[0] - pos[0]))
      .attr('height', Math.abs(@bandPos[1] - pos[1]))

  ###
  # ondragend - the event handler for the ondragend event
  #
  # @param {array} pos, the x,y position of the mouse
  ###
  ondragend: (pos, zoom) ->
    x1 = @plot.axes.xScale.invert(@bandPos[0])
    x2 = @plot.axes.xScale.invert(pos[0])
    if @options.minimumZoom && @options.minimumZoom.hasOwnProperty("x")
      if x1 < @options.minimumZoom.x then x1 = @options.minimumZoom.x
      if x2 < @options.minimumZoom.x then x2 = @options.minimumZoom.x
    if x1 < x2
      @zoomArea.x1 = x1
      @zoomArea.x2 = x2
    else
      @zoomArea.x1 = x2
      @zoomArea.x2 = x1
    y1 = @plot.axes.yScale.invert(pos[1]);
    y2 = @plot.axes.yScale.invert(@bandPos[1])
    if @options.minimumZoom && @options.minimumZoom.hasOwnProperty("y")
      if y1 < @options.minimumZoom.y then y1 = @options.minimumZoom.y
      if y2 < @options.minimumZoom.y then y2 = @options.minimumZoom.y
    if y1 < y2
      @zoomArea.y1 = y1
      @zoomArea.y2 = y2
    else
      @zoomArea.y1 = y2
      @zoomArea.y2 = y1

    @bandPos = [-1, -1];
    @zoomBand.transition()
      .attr('width', 0)
      .attr('height', 0)
      .attr('x', @bandPos[0])
      .attr('y', @bandPos[1])
    if zoom
      @zoom()

  ###
  # zoom - the zooming method called an the end of ondragend
  ###
  zoom: () ->
    @plot.axes.zoom(@zoomArea)
    @plot.draw()

  ###
  # resetZoom - reset the plot zoom back to the original viewBox
  ###
  reset: () ->
    @resetZoomArea()
    @plot.axes.reset()
    @plot.draw()

  ###
  # resetZoomArea - Set all zoomArea properties to 0
  ###
  resetZoomArea: ->
    @zoomArea =
      x1: 0
      y1: 0
      x2: 0
      y2: 0

  ###
  # remove - remove the zoom interface from a plot
  ###
  remove: () ->
    @zoomGroup.remove()
    @drag.on('drag.plot', null)
    @drag.on('end.plot', null)
    @drag.on('start.plot', null)

module.exports = Zoom
