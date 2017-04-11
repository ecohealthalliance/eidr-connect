import d3 from 'd3'
import Plot from '/imports/charts/Plot.coffee'
import Group from '/imports/charts/Group.coffee'

class ScatterPlot extends Plot
  name: 'ScatterPlot'
  ###
  # ScatterPlot - constructs the root SVG element to contain the ScatterPlot
  #
  # @param {object} options, the options to create a ScatterPlot
  # @param {string} containerID, the id of the ScatterPlot container div
  # @param {string} svgcontainerClass, the desired class of the constructed svg element
  # @param {object} tooltip,
  # @param {number} tooltip.opacity, the background opacity for the tooltip
  # @param {object} tooltip.template, the compiled template
  # @param {boolean} scale, scale the svg on window resize @default false
  # @param {boolean} resize, resize the svg on window resize @default true
  # @returns {object} this, returns self
  #
  # example usage:
  #  within your template add
   ```
   <div id="scatterPlot" class="scatterPlot-container">
   ```
  #  within your template helper, construct a new ScatterPlot instance
   ```
  plot = new ScatterPlot(options)
   ```
  #
  # example datetime data:
  ```
    data = [
      {x: 1443380879164, y: 3, w: 1445972879164}, {x: 1467054386392, y: 31, w: 1467659186392}, {x: 1459105926404, y: 15, w: 1469646565130},
      {x: 1443380879164, y: 3, w: 1448654879164}, {x: 1467054386392, y: 31, w: 1468263986392}, {x: 1459105926404, y: 15, w: 1467659365130},
      {x: 1443380879164, y: 3, w: 1451246879164}, {x: 1467054386392, y: 31, w: 1468868786392}, {x: 1459105926404, y: 15, w: 1467918565130},
    ]
  ```
  #
  # example numeric data:
  ```
    data = [
      {x: 0, y: 3, w: 4}, {x: 5, y: 31, w: 9}, {x: 11, y: 45, w: 15},
      {x: 1, y: 3, w: 4}, {x: 5, y: 31, w: 15}, {x: 12, y: 45, w: 14},
      {x: 2, y: 3, w: 4}, {x: 6, y: 31, w: 7}, {x: 12, y: 45, w: 17},
    ]
  ```
  #
  ###
  constructor: (options) ->
    super(options)
    @init()
    @

  ###
  # init - method to set/re-set the resizeHandler
  #
  # @returns {object} this
  ###
  init: () ->
    super()
    resizeEnabled = @options.resize || true
    if resizeEnabled
      @resizeHandler = _.debounce(_.bind(@resize, this), 500)
      window.addEventListener('resize', @resizeHandler)

  ###
  # draw - draw using d3 select.data.enter workflow
  #
  # @param {array} data, an array of {object} for each marker
  # @returns {object} this
  ###
  draw: (data) ->
    super(data)
    # if plot is not zoomed update the axes
    unless @isZoomed()
      @axes.update(@getGroupsNodes())
    groups = @groups.selectAll('.group').data(@getGroups(), (d) -> d.id)
    # create
    groups.enter().append((group) -> group.detached())
    # update
    groups.each((group) -> group.update())
    # remove
    groups.exit().remove()
    #return
    @

  ###
  # update the dimensions of the plot (axes, gridlines, then redraw)
  #
  # @param {array} data, an array of {object} for each marker
  # @returns {object} this
  ###
  update: (data) ->
    super(data)
    @draw(data)
    # return
    @

  ###
  # remove - removes the plot from the DOM and any event listeners
  #
  # @return {object} this
  ###
  remove: () ->
    super()
    if @resizeHandler
      window.removeEventListener('resize', @resizeHandler)
    @

  ###
  # resize - re-renders the plot
  #
  # @return {object} this
  ###
  resize: () ->
    @update()
    @

  ###
  # resetZoom - resets the zoom of the axes
  ###
  resetZoom: () ->
    #if !@data || @data.length <= 0
    #  return
    if @zoom
      @zoomed?.set(false)
      @zoom.reset()

  ###
  # resetZoom - Checks zoomArea and returns 0 if no current area selected
  ###
  isZoomed: ->
    zoomed = _.compact(_.values(@zoom.zoomArea)).length
    @zoomed?.set(zoomed)
    zoomed

module.exports = ScatterPlot
