import d3 from 'd3'
import Grid from '/imports/charts/Grid.coffee'

class Axes
  ###
  # Axes
  #
  # constructs 2d cartesian axes, appends to the container SVG element of the plot
  #
  # @param {object} plot, the plot to append the axis
  # @param {object} options, the properties for the axis
  # @param {boolean} grid, should the grid be displayed?
  # X axis properties
  # @param {object} options.axes.x, the properties for x axis
  # @param {string} options.axes.x.title, the title of the x axis
  # @param {string} options.axes.x.type, the datatype of the x axis {numeric, datetime}
  # Y axis properties
  # @param {object} options.axes.y, the properties for y axis
  # @param {string} options.axes.y.title, the title of the y axis
  # @param {string} options.axes.y.type, the datatype of the y axis {numeric, datetime}
  #
  # @returns {object} this, returns self
  #
  # example usage:
  #  with an instance of a plot:
    ```
    axes = new Axes(plot, {
      axes: {
        grid: true,
        x: {
          title: 'Time',
          type: 'datetime',
          minMax: [1443371126, 1474993537]
        },
        y: {
          title: 'Incidents',
          type: 'numeric',
          minMax: [0, 100]
        },
      }
    })
    ```
  #
  ###
  constructor: (plot, options) ->
    @plot = plot
    @options = options || {x: {title: 'x', type: 'numeric'}, y: {title: 'y', type: 'numeric'}, grid: true, filter: true}
    @initialized = false
    @initialMinMax = [[0,0],[0,0]]
    @currentMinMax = [[0,0],[0,0]]
    @init()

  ###
  # init - initialize the plot x,y axes
  #
  # @param {array} xDomain, the zoom xDomain or undefined
  # @param {array} yDomain, the zoom yDomain or undefined
  ###
  init: (xDomain, yDomain) ->
    # xScale
    if @options.x.type == 'datetime'
      if xDomain
        @xScale = d3.scaleTime().domain(xDomain).range([0, @plot.getWidth()]).nice()
      else
        @xScale = d3.scaleTime().domain(@currentMinMax[0]).range([0, @plot.getWidth()]).nice()
    else
      if xDomain
        @xScale = d3.scaleLinear().domain(xDomain).range([0, @plot.getWidth()])
      else
        @xScale = d3.scaleLinear().domain(@currentMinMax[0]).range([0, @plot.getWidth()])

    # xAxis
    if @options.x.type == 'datetime'
      @xAxis = d3.axisBottom()
        .scale(@xScale)
        .ticks(10)
        .tickFormat(d3.timeFormat(@formatDate()))
    else
      @xAxis = d3.axisBottom()
        .scale(@xScale)
        .ticks(10)

    # xGroup
    if @options.x.type == 'datetime'
      @xGroup = @plot.container.append('g')
        .attr('class', 'x scatterPlot-axis')
        .attr('transform', "translate(#{@plot.margins.left}, #{@plot.getHeight()})")
        .call(@xAxis)
      @xGroup.selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.8em')
        .attr('dy', '.15em')
        .attr('transform', (d) -> 'rotate(-65)')
    else
      @xGroup = @plot.container.append('g')
        .attr('class', 'scatterPlot-axis')
        .attr('transform', "translate(#{@plot.margins.left}, #{@plot.getHeight()})")
        .call(@xAxis)

    # yScale
    if yDomain
      @yScale = d3.scaleLinear()
        .domain(yDomain)
        .range([@plot.getHeight(), 0])
    else
      @yScale = d3.scaleLinear()
        .domain(@currentMinMax[1])
        .range([@plot.getHeight(), 0])

    # yAxis
    @yAxis = d3.axisLeft()
      .scale(@yScale)
    # yGroup
    @yGroup = @plot.container.append('g')
      .attr('class', 'y scatterPlot-axis')
      .attr('transform', "translate(#{@plot.margins.left}, 0)")
      .call(@yAxis)
    # xLabel
    if !@xLabel
      padding = 0
      if @options.x.type == 'datetime'
        padding = 45
      @xLabel =  @plot.container
        .append('g')
          .attr('class', 'x scatterPlot-axis-label')
          .attr('transform', "translate(#{@plot.margins.left}, #{@plot.getHeight() + padding})")
        .append('text')
          .attr('dx', (@plot.width / 2) - (@plot.margins.right + @plot.margins.left) / 2)
          .attr('dy', @plot.margins.bottom)
          .attr('class', 'scatterPlot-axis-label')
          .style('text-anchor', 'middle')
          .text( =>
            @options.x.title || ''
          )

    # yLabel
    if !@yLabel
      @yLabel = @plot.container
        .append('g')
          .attr('class', 'y scatterPlot-axis-label')
          .attr('transform', "translate(#{@plot.margins.left - 15}, 0)")
        .append('text')
          .attr('transform', 'rotate(-90)')
          .attr('dx', -(@plot.height / 2) + (@plot.margins.top + @plot.margins.bottom) / 2)
          .attr('dy', -@plot.margins.left)
          .attr('class', 'scatterPlot-axis-label')
          .style('text-anchor', 'middle')
          .text( =>
            @options.y.title || ''
          )

    # the x,y grid lines, requires the instance of the axes
    if @options.grid
      @grid = new Grid(@, @plot)

  ###
  # setDomain - sets the x, y domains based on the passed in data
  #
  # @param {array} data, an array of {object} for each marker
  ###
  setDomain: (data) ->
    if @options.x.type == 'datetime'
      xMin = Axes.minDatetime(_.pluck(data, 'x'))
      # check for 'width' property on the x-axis
      w = _.pluck(data, 'w')
      if w.length > 0
        xMax = Axes.maxDatetime(_.pluck(data, 'w'))
      else
        xMax = Axes.maxDatetime(_.pluck(data, 'x'))
    else
      xMin = 0
      # check for 'width' property on the x-axis
      w = _.pluck(data, 'w')
      if w.length > 0
        xMax = Axes.maxNumeric(_.pluck(data, 'w'))
      else
        xMax = Axes.maxNumeric(_.pluck(data, 'x'))
    yMin = 0
    yMax = Axes.maxNumeric(_.pluck(data, 'y'))
    @xScale.domain([xMin, xMax])
    @yScale.domain([yMin, yMax])
    # add the filter the first time the domain is set
    if @initialized == false
      @initialMinMax = [[xMin, xMax], [yMin, yMax]]
      if @options.filter
        @plot.addFilter '_domain', (d) ->
          x1 = @axes.xScale.domain()[0]
          if x1 instanceof Date
            x1 = x1.getTime()
          x2 = @axes.xScale.domain()[1]
          if x2 instanceof Date
            x2 = x2.getTime()
          y1 = @axes.yScale.domain()[0]
          y2 = @axes.yScale.domain()[1]
          if d.hasOwnProperty('w')
            if ((d.x >= x1 && d.w <= x2) && (d.y >= y1 && d.y <= y2))
              return d
          else
            if ((d.x >= x1 && d.x <= x2) && (d.y >= y1 && d.y <= y2))
              return d
    else
      @currentMinMax = [[xMin, xMax], [yMin, yMax]]

    @initialized = true

  ###
  # setDomain - sets the x, y domains based on the passed in data
  # @note this will overwrite the original x,y minMax options to the plot
  #
  # @param {array} data, an array of {object} for each marker
  ###
  setInitialMinMax: (newMinMax) ->
    @initialMinMax = newMinMax

  ###
  # update - update the x,y axes using the zoom domain
  #
  # @param {array} data, an array of {object} for each marker
  ###
  update: (data) ->
    @remove()
    if data
      @setDomain(data)
    @init(@xScale.domain(), @yScale.domain())
    @

  ###
  # reset - resets the x,y axes back to the original domain
  ###
  reset: () ->
    @remove()
    @init(@initialMinMax[0], @initialMinMax[1])
    @

  ###
  # zoom - zooms the x,y axes based on the zoomArea object
  #
  # @param {object} zoomArea, an object containing a bounding box of x,y coordinates
  ###
  zoom: (zoomArea) ->
    if zoomArea.x1 > zoomArea.x2
      @xScale.domain([zoomArea.x2, zoomArea.x1])
    else
      @xScale.domain([zoomArea.x1, zoomArea.x2])

    if @options.x.type == 'datetime'
      @xAxis.tickFormat(d3.timeFormat(@formatDate()))

    if zoomArea.y1 > zoomArea.y2
      @yScale.domain([zoomArea.y2, zoomArea.y1])
    else
      @yScale.domain([zoomArea.y1, zoomArea.y2])
    trans = @plot.container.transition().duration(750)
    @xGroup.transition(trans).call(@xAxis)
    @xGroup.selectAll('.tick').selectAll('text')
      .style('text-anchor', 'end')
      .attr('dx', '-.8em')
      .attr('dy', '.15em')
      .attr('transform', 'rotate(-65)')
    @yGroup.transition(trans).call(@yAxis)

    if @grid
      @grid.remove()
      @grid = new Grid(@, @plot)
    # return
    @

  ###
  # remove - removes the x,y axis groups from the plot
  ###
  remove: () ->
    @xGroup.remove()
    @yGroup.remove()
    if @grid
      @grid.remove()

  ###
  # formatDate - a method that formats the axis date label
  ###
  formatDate: () ->
    xDomain = @xScale.domain()
    duration = moment.duration(moment(xDomain[1]).diff(xDomain[0])).asDays()
    if duration <= 7
      return '%b %d - %H:%M'
    return '%b %d, %Y'

###
# maxNumeric - determine the maximum value with padding. Padding is determined
# by the number of digits ^ 10 / 10, unless number of digets == 10 then return
# 10
#
# @param {array} data, an array of positive integers
# @return {number} max
###
Axes.maxNumeric = (data) ->
  m = _.max(data)
  l = String(m).split('').length
  # if the length of the number is 1, (e.g 0 ... 9) then return 10
  if l == 1
    return 10
  p = (Math.pow(10, l)) / 10
  m + p

###
# minNumeric - determine the minimum value with padding. Padding is determined
# by the number of digits ^ 10 / 10, unless number of digets == 10 then return
# 10
#
# @param {array} data, an array of positive integers
# @return {number} max
###
Axes.minNumeric = (data) ->
  m = _.min(data)
  l = String(m).split('').length
  # if the length of the number is 1, (e.g 0 ... 9) then return 10
  if l == 1
    return 10
  p = (Math.pow(10, l)) / 10
  m + p

###
# getDatetimeUnit - determine the unit of time for padding the axis
#
# @param {object} min, the min moment datetime object
# @param {object} max, the max moment datetime object
# @return {string} the datetime unit {day, week, month}
###
getDatetimeUnit = (min, max) ->
  diff = max.diff(min, 'days')
  unit = 'month' # one of {day, week, month} default is month
  if diff <= 14
    unit = 'day'
  else if diff > 14 and diff <= 183
    unit = 'week'
  unit

###
# maxDatetime - determine the maximum value with padding
#
# @param {array} data, an array of timestamps in milliseconds
# @return {number} max, maximum datetime value
###
Axes.maxDatetime = (data) ->
  min = moment(_.min(data))
  max = moment(_.max(data))
  unit = getDatetimeUnit(min, max)
  moment(max).add(1, unit).valueOf()

###
# minDatetime - determine the minimum value with padding
#
# @param {array} data, an array of timestamps in milliseconds
# @return {number} min, minimum datetime value
###
Axes.minDatetime = (data) ->
  min = moment(_.min(data))
  max = moment(_.max(data))
  unit = getDatetimeUnit(min, max)
  moment(min).subtract(1, unit).valueOf()


module.exports = Axes
