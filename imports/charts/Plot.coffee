import d3 from 'd3'
import Axes from '/imports/charts/Axes.coffee'
import Zoom from '/imports/charts/Zoom.coffee'
import Group from '/imports/charts/Group.coffee'
import { InvalidGroupError } from '/imports/charts/Errors.coffee'

MINIMUM_PLOT_HEIGHT = 300

class Plot
  name: 'Plot'
  ###
  # Plot - creates a new instance of a plot
  #
  # @param {object} options, the options to create a ScatterPlot
  # @param {string} containerID, the id of the ScatterPlot container div
  # @param {string} svgcontainerClass, the desired class of the constructed svg element
  # @param {object} tooltip,
  # @param {number} tooltip.opacity, the background opacity for the tooltip
  # @param {object} tooltip.template, the compiled template
  # @param {boolean} scale, scale the svg on window resize @default false
  # @param {boolean} resize, resize the svg on window resize @default true
  #
  # @returns {object} this, returns self
  ###
  constructor: (options) ->
    @options = options
    @drawn = false
    @filters = options.filters || {}
    @groups_ = {}
    @

  ###
  # init - method to initialize the plot, allows the plot to be re-initialized
  #  on resize while keeping the current plot data in memory
  #
  # @returns {object} this
  ###
  init: () ->
    # dimensions of the plot
    @setDimensions()

    # should we scale the svg by aspectRatio?
    scale = @options.scale || false

    # the root elment of the plot
    if scale
      @root = d3.select("\##{@options.containerID}").append('svg')
        .attr('viewBox', "0 0 #{@viewBoxWidth} #{@viewBoxHeight}")
        .attr('preserveAspectRatio','xMinYMin meet')
    else
      @root = d3.select("\##{@options.containerID}").append('svg')
        .attr('width', @viewBoxWidth)
        .attr('height', @viewBoxHeight)
    @root.style('opacity', 0)

    # the container of the plot
    @container = @root.append('g')
      .attr('class', @options.svgContainerClass)
      .attr('width', @getWidth())
      .attr('height', @getHeight())
      .attr('transform', "translate(#{@margins.left}, #{@margins.top})")

    # the axes of the plot
    @axes = new Axes(@, @options.axes)

    # is zoom enabled?
    zoomEnabled = @options.zoom || false
    if zoomEnabled
      @zoom = new Zoom(@, @options)

    @zoomed = @options.zoomed or new ReactiveVar(false)

    # an svg container for the plot's groups
    @groups = @container.append('g')
      .attr('class', 'scatterPlot-groups')
      .attr('transform', "translate(#{@margins.left}, 0)")

    # return
    @

  ###
  # setDimensions - method to set the dimensions of the plot based on the current window
  ###
  setDimensions: () ->
    @margins = @options.margins || {left: 40, right: 20, top: 20, bottom: 40}
    @width = @options.width || document.getElementById(@options.containerID).offsetWidth - (@margins.left + @margins.right);
    @height = @options.height || Plot.aspectRatio() * @width
    if @height < MINIMUM_PLOT_HEIGHT
      @height = MINIMUM_PLOT_HEIGHT
    @viewBoxWidth = @width + @margins.left + @margins.right
    @viewBoxHeight = @height + @margins.top + @margins.bottom
    @

  ###
  # update - update the width and height attributes of the root and container
  #  elements. then call update on the plot axes
  #
  # @param {array} nodes, an array of {object} for each node
  # @returns {object} this
  ###
  update: (nodes) ->
    @setDimensions()
    @root
      .attr('width', @viewBoxWidth)
      .attr('height', @viewBoxHeight)
    @container
      .attr('width', @width)
      .attr('height', @height)
      .attr('transform', "translate(#{@margins.left}, #{@margins.top})")
    if typeof nodes != 'undefined'
      if nodes instanceof Array
        @axes.update(nodes)
      else
        shouldSetInitialMinMax = @mergeGroups(nodes)
        @axes.update(@getGroupsNodes(false))
        if shouldSetInitialMinMax
          @axes.setInitialMinMax(@axes.currentMinMax)
    else
      @axes.update(@getGroupsNodes())
    #return
    @

  ###
  # draw - draws the markers on the plot
  #
  # @note this will automatically show/hide a warning message if the data
  # is empty. Do not call super() to override this behavior.
  #
  # @param {array} nodes, an array of {object} for each marker
  ###
  draw: (nodes) ->
    if !@drawn
      @drawn = true
      @root.transition().style('opacity', 1)
    if typeof nodes != 'undefined'
      if nodes instanceof Array
        group = @defaultGroup(nodes)
        if group.size() <= 0
          @showWarn()
          return
      else
        if @getGroupsSize() <= 0
          @showWarn()
          return
    else
      if @getGroupsSize() <= 0
        @showWarn()
        return
    @removeWarn()

  ###
  # defaultGroup - creats a defaul group for data passed directly to the draw
  #   method
  #
  # @param {array} nodes, an array of Node's
  ###
  defaultGroup: (nodes) ->
    group = @getGroups().find((group) -> group.id == 'default_')
    if typeof group == 'undefined'
      group = new Group(@, {id: 'default_', onEnter: @options.group.onEnter})
    nodes.forEach((d) -> group.addNode(d))
    #return
    group

  ###
  # mergeGroups - merge groups from data passed directly to the draw method
  #
  # @param {object} nodes, a grouping of nodes
  # @return {boolean} shouldReset, should the axes domain be reset to currentMinMax
  ###
  mergeGroups: (groups) ->
    notMerged = Object.keys(@groups_)
    hasNewGroup = false
    Object.keys(groups).forEach (k) =>
      group = @groups_[k]
      if typeof group == 'undefined'
        hasNewGroup = true
        group = new Group(@, {id: k, onEnter: @options.group.onEnter})
      else
        idx = notMerged.indexOf(k)
        if idx >= 0
          notMerged.splice(idx, 1)
      groups[k].forEach((m) -> group.addNode(m))
    if notMerged.length > 0
      # remove groups that haven't been merged
      notMerged.forEach((k) => @removeGroup(k))
      return true
    if hasNewGroup and @axes.initialized == true
      return true
    else
      return false

  ###
  # getWidth
  #
  # @return {number} width (excluding margins) for the root svg
  ###
  getWidth: () ->
    @width - (@margins.left + @margins.right)

  ###
  # getHeigth
  #
  # @return {number} width (excluding margins) for the root svg
  ###
  getHeight: () ->
    @height - (@margins.top + @margins.bottom)

  ###
  # showWarn - shows a warning message in the center of the plot
  #
  # @param {string} m, the message to display
  # @return {object} this
  ###
  showWarn: (m) ->
    if typeof m == 'undefined'
      m = 'No data to display'
    if @warn
      @removeWarn()
    @warn = @container.append('g')
      .style('opacity', 0)
      .attr('class', 'scatterPlot-warn')
    text = @warn.append('text')
      .attr('text-anchor', 'middle')
      .attr('x', @width / 2)
      .attr('y', @getHeight() / 2)
      .text(m)
    @warn.transition().style('opacity', 1)
    @

  ###
  # removeWarn - removes the warning message from the plot
  #
  # @return {object} this
  ###
  removeWarn: () ->
    if @warn
      @warn.remove()
    @

  ###
  # remove - removes the plot from the DOM and any event listeners
  #
  # @return {object} this
  ###
  remove: () ->
    @zoom.remove()
    @axes.remove()
    @container.remove()
    @root.remove()

  ###
  #  destroy - destroys the plot and any associated elements
  ###
  destroy: () ->
    @remove()
    @zoom = null
    @tooltip = null
    @axes = null
    @container = null
    @root = null
    @resizeHandler = null

  ###
  # addGroup
  #
  # @param {object} group, add a group to the plot
  # @throws {InvalidGroupError} error
  # @return {Plot} this
  ###
  addGroup: (group) ->
    if group instanceof Group == false
      throw new InvalidGroupError()
    @groups_[group.id] = group
    # return
    @

  ###
  # removeGroup
  #
  # @param {string} id, the group to remove
  ###
  removeGroup: (id) ->
    if @groups_.hasOwnProperty(id)
      delete @groups_[id]

  ###
  # getGroups - returns the groups associated with this plot
  #
  # @return {array} groups, the groups associated with this plot
  ###
  getGroups: () ->
    return Object.values(@groups_)

  ###
  # getGroups - returns the size of all the groups
  #
  # @param {boolean} shouldFilter, should the nodes be filtered by domain
  # @return {Number} size, the size of all the groups
  ###
  getGroupsSize: (shouldFilter) ->
    @getGroups().reduce((prev, nextObj) =>
      if shouldFilter
        return prev + nextObj.applyFilters().length
      else
        filters = Object.assign({}, @filters)
        if filters.hasOwnProperty('_domain')
          delete filters['_domain']
        return prev + nextObj.applyFilters(filters).length
    , 0)

  ###
  # getGroupsNodes - returns all the nodes for each group
  #
  # @param {boolean} shouldFilter, should the nodes be filtered by domain
  # @return {array} nodes, an array of nodes
  ###
  getGroupsNodes: (shouldFilter) ->
    @getGroups().reduce((prevArr, nextObj) =>
      if shouldFilter
        return prevArr.concat(nextObj.applyFilters())
      else
        filters = Object.assign({}, @filters)
        if filters.hasOwnProperty('_domain')
          delete filters['_domain']
        return prevArr.concat(nextObj.applyFilters(filters))
    , [])

  ###
  # addFilter - add a filter to the plot
  #
  # @param {string} name, the name of the filter
  # @param {function} fn, the function to be applied to the data
  # @return {object} this
  ###
  addFilter: (name, fn) ->
    @filters[name] = _.bind(fn, @)
    @

  ###
  # removeFilter - removes a filter from the plot
  #
  # @param {string} name, the name of the filter
  # @return {object} this
  ###
  removeFilter: (name) ->
    if @filters[name] != 'undefined'
      delete @filters[name]
    @


# find the view port aspect ratio
#
# @return {number} aspectRatio
Plot.aspectRatio = () ->
  $(window).height() / $(window).width()


module.exports = Plot
