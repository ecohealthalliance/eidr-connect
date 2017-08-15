import d3 from 'd3'
import Node from '/imports/charts/Node.coffee'

MINIMUM_LINE_STROKE = 4
MINIMUM_LINE_WIDTH = 4
MINIMUM_CIRCLE_RADIUS = 5
MINIMUM_LINE_THRESHOLD = 2

class SegmentMarker extends Node
  ###
  # SegmentMarker - a line marker with beginning and end
  #
  # @param {object} options, the options used to construct the SegmentMarker
  # @param {number} options.x, the value for x position
  # @param {number} options.y, the value for y position
  # @param {number} options.l, the value for the length of the line
  # @param {number} options.h, the value for the height
  # @param {string} options.f, the fill of the line
  # @param {number} options.o, the opacity of the line
  # @param {object} options.meta, the optional meta data associated with the marker (e.g. used in the Tooltip)
  # @return {object} this
  ###
  constructor: (plot, options) ->
    super(options)
    @plot = plot
    @x = options.x
    @y = options.y
    @w = options.w
    @h = options.h || MINIMUM_LINE_STROKE
    @r = options.r || MINIMUM_CIRCLE_RADIUS
    @f = options.f || '#345e7e'
    @o = options.o || 0.3
    @meta = options.meta || {}

    #return
    @

  ###
  # remove - removes the marker from the DOM
  #
  # @return {object} this
  ###
  remove: () ->
    if @group
      @group.remove()

  ###
  # filteredOrderedPair - determine if the pair exists within the domain
  ###
  filteredOrderedPair: (orderedPair) ->
    if orderedPair[0] < @plot.axes.xScale.range()[0]
      orderedPair[0] = null
    if orderedPair[0] > @plot.axes.xScale.range()[1]
      orderedPair[0] = null
    if orderedPair[1] < @plot.axes.yScale.range()[1]
      orderedPair[1] = null
    if orderedPair[1] > @plot.axes.yScale.range()[0]
      orderedPair[1] = null
    orderedPair

  ###
  # update - handles updating the marker
  #
  # @return {object} this
  ###
  update: () ->
    if typeof @group == 'undefined'
      @group = d3.select("##{@id}")

    linePairs = [[@plot.axes.xScale(@x), @plot.axes.yScale(@y)], [@plot.axes.xScale(@w), @plot.axes.yScale(@y)]]
    lineDistance = @distance(linePairs)
    totalRange = @plot.axes.xScale.range()[1]
    linePercentage = Math.floor((lineDistance / totalRange) * 100)

    startPoint = @filteredOrderedPair([@plot.axes.xScale(@x), @plot.axes.yScale(@y)])

    # check the domain of the startPoint, if it contains a null value, it shouldn't be displayed
    start = @group.selectAll('.start-circle').data([@], (d) -> d.id)
    if startPoint[0] != null && startPoint[1] != null
      # create
      start.enter().append('circle')
        .attr('class', 'start-circle')
        .style('fill', @f)
        .attr('cx', startPoint[0])
        .attr('cy', startPoint[1])
        .attr('r', (d) =>
          radius = @r
          radius = Math.ceil((radius * (linePercentage / 100)) + radius)
          if radius < MINIMUM_CIRCLE_RADIUS
            radius = MINIMUM_CIRCLE_RADIUS
          radius
        )
      # update
      start
        .attr('cx', startPoint[0])
        .attr('cy', startPoint[1])
        .attr('r', (d) =>
          radius = @r
          radius = Math.ceil((radius * (linePercentage / 100)) + radius)
          if radius < MINIMUM_CIRCLE_RADIUS
            radius = MINIMUM_CIRCLE_RADIUS
          radius
        )
      # remove
      start.exit().remove()
    else
      @group.selectAll('.start-circle').remove()

    if linePercentage >= MINIMUM_LINE_THRESHOLD
      line = @group.selectAll('line').data([@], (d) -> d.id)
      # create
      line.enter().append('line')
        .attr('x1', () =>
          if linePairs[0][0] <= @plot.axes.xScale.range()[0]
            return @plot.axes.xScale.range()[0]
          if linePairs[0][0] >= @plot.axes.xScale.range()[1]
            return null
          linePairs[0][0]
        )
        .attr('y1', linePairs[0][1])
        .attr('x2', () =>
          if linePairs[1][0] >= @plot.axes.xScale.range()[1]
            return @plot.axes.xScale.range()[1]
          if linePairs[1][0] <= @plot.axes.xScale.range()[0]
            return null
          linePairs[1][0]
        )
        .attr('y2', linePairs[1][1])
        # the thickness of the line
        .attr('stroke-width', () =>
          height = @h
          height = Math.ceil((height * (linePercentage / 100)) + height)
          if height < MINIMUM_LINE_STROKE
            return MINIMUM_LINE_STROKE
          height
        )
        .attr('stroke', @f)
      # update
      line
        .attr('x1', () =>
          if linePairs[0][0] <= @plot.axes.xScale.range()[0]
            return @plot.axes.xScale.range()[0]
          if linePairs[0][0] >= @plot.axes.xScale.range()[1]
            return null
          linePairs[0][0]
        )
        .attr('y1', linePairs[0][1])
        .attr('x2', () =>
          if linePairs[1][0] >= @plot.axes.xScale.range()[1]
            return @plot.axes.xScale.range()[1]
          if linePairs[1][0] <= @plot.axes.xScale.range()[0]
            return null
          linePairs[1][0]
        )
        .attr('y2', linePairs[1][1])
        # the thickness of the line
        .attr('stroke-width', () =>
          height = @h
          height = Math.ceil((height * (linePercentage / 100)) + height)
          if height < MINIMUM_LINE_STROKE
            return MINIMUM_LINE_STROKE
          height
        )
    else
      # we shouldn't have any lines in this group
      @group.selectAll('line').remove()

    # check the domain of the endPoint, if it contains a null value, it shouldn't be displayed
    endPoint = @filteredOrderedPair([@plot.axes.xScale(@w), @plot.axes.yScale(@y)])
    if linePercentage >= MINIMUM_LINE_THRESHOLD
      if endPoint[0] != null && endPoint[1] != null
        end = @group.selectAll('.end-circle').data([@], (d) -> d.id)
        # create
        end.enter().append('circle')
          .attr('class', 'end-circle')
          .attr('cx', endPoint[0])
          .attr('cy', endPoint[1])
          .attr('r', () =>
            radius = @r
            radius = Math.ceil(((radius * linePercentage) / 100) + radius)
            if radius < MINIMUM_CIRCLE_RADIUS
              radius = MINIMUM_CIRCLE_RADIUS
            return radius
          )
          .style('fill', @f)
        # update
        end
          .attr('class', 'end-circle')
          .attr('cx', endPoint[0])
          .attr('cy', endPoint[1])
          .attr('r', () =>
            radius = @r
            radius = Math.ceil(((radius * linePercentage) / 100) + radius)
            if radius < MINIMUM_CIRCLE_RADIUS
              radius = MINIMUM_CIRCLE_RADIUS
            return radius
          )
      else
        # we shouldn't have any end circles in this group
        @group.selectAll('.end-circle').remove()
    else
      # we shouldn't have any end circles in this group
      @group.selectAll('.end-circle').remove()

    #return
    @

  ###
  # detached - builds a detached svg group and returns the node
  #
  # @return {object} node, the SVG node to append to the parent during .call()
  ###
  detached: () ->
    @remove()
    @group = d3.select(document.createElementNS(d3.namespaces.svg, 'g'))
      .attr('id', @id)
      .attr('class', 'node')
      .attr('opacity', @o).remove()
    @update()
    #return
    @group.node()

  ###
  # distance - determine the distance between two pairs
  ###
  distance: (pairs) ->
    Math.sqrt((Math.pow(Math.abs(pairs[0][0] - pairs[1][0]), 2) + Math.pow(Math.abs(pairs[0][1] - pairs[1][1]), 2)))

###
# createFromIncident - method to construct a SegmentMarker from an incident
#
# @param {object} incident, the incident used to create a marker
# @return {object} SegmentMarker, the marker that is created
###
SegmentMarker.createFromIncident = (plot, incident) ->
  if typeof incident == 'undefined'
    return
  if typeof incident.dateRange != 'object'
    return
  m = {
    id: "node-#{incident._id}"
    meta: {}
  }
  x = -1
  w = -1
  if incident.dateRange.type == 'precise'
    x = moment(incident.dateRange.start).valueOf()
    w = moment(incident.dateRange.end).valueOf()
  else if incident.dateRange.type == 'day'
    x = moment(incident.dateRange.start).hours(0).valueOf()
    w = moment(incident.dateRange.start).hours(0).add(24, 'hours').valueOf()
  if x <= 0 || w <= 0
    return
  m.x = x
  m.w = w
  m.y = 0
  if typeof incident.cases != 'undefined'
    m.meta.type = 'case'
    m.f = '#345e7e'
    m.y += incident.cases
  else if typeof incident.deaths != 'undefined'
    m.meta.type = 'death'
    m.f = '#f07382'
    m.y += incident.deaths
  else
    return
  m.meta.incident = incident
  m.meta.cumulative = incident.dateRange.cumulative
  new SegmentMarker(plot, m)

###
# groupOverlappingSegments - group overlapping segments together
#
# @param {array} segments, an array of SegmentMarker's
# @return {object} groups, groups of overlapping segments
###
SegmentMarker.groupOverlappingSegments = (segments) ->
  groups = {}
  # first group segments by their y-axis value
  segmentsByHeightAndCumulative = _.groupBy(segments, (segment) ->
    if typeof segment.meta.cumulative == 'undefined'
      c = false
    else
      c = segment.meta.cumulative
    return segment.y + ':' + c
  )
  # determine if they are overlapping
  for key of segmentsByHeightAndCumulative
    values = segmentsByHeightAndCumulative[key]
    # sort the values by ascending x1
    values.sort((a, b) -> a.x - b.x)
    i = 0
    # determine overlapping segments within the y-axis group
    points = []
    while i < values.length
      if i == 0
        points[0] = values[0]
        groupName = '' + values[0].w + ':' + key
        groups[groupName] = [values[0]]
        i++
        continue
      lastIdx = points.length - 1
      if lastIdx < 0
        break
      lastPoint = points[lastIdx]
      if values[i].x >= lastPoint.x && values[i].w <= lastPoint.w
        groupName = '' + lastPoint.w + ':' + key
        group = groups[groupName]
        if typeof group == 'undefined'
          group = []
        group.push(values[i])
        i++
      else
        points[lastIdx+1] = values[i]
        groupName = '' + values[i].w + ':' + key
        groups[groupName] = [values[i]]
        i++
  #return
  groups


module.exports = SegmentMarker
