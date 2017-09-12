import Rickshaw from 'meteor/eidr:rickshaw.min'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials'
import {
  differentailIncidentsToSubIntervals,
  extendSubIntervalsWithValues
} from '/imports/incidentResolution/incidentResolution'
import LocationTree from '/imports/incidentResolution/LocationTree'
import EventIncidents from '/imports/collections/eventIncidents'
import Constants from '/imports/constants'

sortComponentTreeChildren = (componentTree) ->
  componentTree.children = _.sortBy(componentTree.children, (x) -> -x.associatedObject.value)
  componentTree.children.forEach(sortComponentTreeChildren)

Template.eventResolvedIncidents.onCreated ->
  @incidentType = new ReactiveVar("cases")
  @plotType = new ReactiveVar("rate")
  @legend = new ReactiveVar([])
  @loading = new ReactiveVar(false)
  @tooManyIncidents = new ReactiveVar(false)
  @highlightedLocations = new Meteor.Collection(null)
  @differentialIncidents = new ReactiveVar([])

Template.eventResolvedIncidents.onRendered ->
  renderPlot = (differentials, locToSubintervals, locationTree, topLocations) =>
    plotType = @plotType.get()
    @$('.chart').html('''<div class="y-axis"></div>
      <div class="graph"></div>
      <div class="slider"></div>
      <div class="legend"></div>''')
    palette = new Rickshaw.Color.Palette(
      scheme: 'colorwheel'
      interpolatedStopCount: topLocations.length
    )
    pairedLocs = _.pairs(locToSubintervals)
    @legend.set(pairedLocs.map ([key], sIdx) =>
      name: locationTree.getLocationById(key).name
      color: if @highlightedLocations.findOne(key) or @highlightedLocations.find().count() == 0
        palette.color(sIdx)
      else
        '#999999'
      id: key
    )
    graph = new Rickshaw.Graph({
      element: @$('.graph')[0]
      renderer: 'multi'
      stack: false
      interpolation: 'linear'
      dotSize: 5
      strokeWidth: 2
      series: pairedLocs.map ([key, locSubIntervals], sIdx) =>
        MILLIS_PER_DAY = 1000 * 60 * 60 * 24
        location = locationTree.getLocationById(key)
        groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
        maxSubintervals = []
        for group, subIntervalGroup of groupedLocSubIntervals
          maxSubintervals.push(_.max(subIntervalGroup, (x) -> x.value))
        maxSubintervals = _.sortBy(maxSubintervals, (x) -> x.start)
        if plotType == 'rate'
          formattedData = _.chain(_.zip(maxSubintervals, maxSubintervals.slice(1)))
            .map(([subInt, iNext]) ->
              onClick = ->
                concurrentIntervals = groupedLocSubIntervals[subInt.start] or []
                componentTree = LocationTree.from(concurrentIntervals.map (x) -> x.location)
                concurrentIntervals.forEach (x) ->
                  componentTree.getNodeById(x.location.id).associatedObject = x
                sortComponentTreeChildren(componentTree)
                Modal.show('intervalDetailsModal',
                  interval: subInt
                  componentTree: componentTree
                  incidents: subInt.incidentIds.map (id) ->
                    differentials[id]
                )
              days = (subInt.end - subInt.start) / MILLIS_PER_DAY
              rate = subInt.value / days
              result = [
                {x: subInt.start / 1000, y: rate, onClick: onClick}
                {x: subInt.end / 1000, y: rate, onClick: onClick}
              ]
              if iNext and subInt.end != iNext.start
                result.push {x: subInt.end / 1000, y:0}
                result.push {x: iNext.start / 1000, y:0}
              result
            )
            .flatten(true)
            .reduce((sofar, cur) ->
              prev = sofar.slice(0)[1]
              if prev and prev.x == cur.x
                cur.x += 1
                sofar.concat([cur])
              else
                sofar.concat([cur])
            , [])
            .value()
        else
          total = 0
          formattedData = _.chain(maxSubintervals)
            .map((subInt) ->
              onClick = ->
                concurrentIntervals = groupedLocSubIntervals[subInt.start] or []
                componentTree = LocationTree.from(concurrentIntervals.map (x) -> x.location)
                concurrentIntervals.forEach (x) ->
                  componentTree.getNodeById(x.location.id).associatedObject = x
                sortComponentTreeChildren(componentTree)
                Modal.show('intervalDetailsModal',
                  interval: subInt
                  componentTree: componentTree
                  incidents: subInt.incidentIds.map (id) ->
                    differentials[id]
                )
              days = (subInt.end - subInt.start) / MILLIS_PER_DAY
              rate = subInt.value / days
              newTotal = total + subInt.value
              result = [
                {x: subInt.start / 1000, y: total, onClick: onClick}
                {x: subInt.end / 1000, y: newTotal, onClick: onClick}
              ]
              total = newTotal
              result
            )
            .flatten(true)
            .value()
        disabled = false
        if @highlightedLocations.find().count() != 0
          if not(@highlightedLocations.findOne(key))
            disabled = true
        return {
          name: location.name
          color: palette.color(sIdx)
          disabled: disabled
          renderer: 'line'
          data: formattedData
        }
    })
    slider = new Rickshaw.Graph.RangeSlider.Preview(
      graph: graph
      element: @$('.slider')[0]
    )
    detail = new Rickshaw.Graph.HoverDetail(
      graph: graph
    )
    new Rickshaw.Graph.Axis.Time(
      graph: graph
    )
    new Rickshaw.Graph.Axis.Y(
      graph: graph
    )
    new Rickshaw.Graph.HoverDetail(
      graph: graph
      formatter: (series, x, y, formattedX, formattedY, obj) =>
        @hoveredIntervalClickEvent = obj.value.onClick
        if plotType == 'rate'
          "#{series.name}: #{y.toFixed(2)} cases per day"
        else
          "#{series.name}: #{y.toFixed(0)} cases"
    )
    graph.render()

  @autorun =>
    @incidents = EventIncidents.find(@data.filterQuery.get())
    incidentType = @incidentType.get()
    allIncidents = @incidents.fetch()
    allIncidents = allIncidents.filter (i) ->
      i.locations.every (l) -> l.featureCode
    differentialIncidents = convertAllIncidentsToDifferentials(allIncidents)
    @differentialIncidents.set(differentialIncidents)

  @autorun =>
    @hoveredIntervalClickEvent = null
    incidentType = @incidentType.get()
    differentialIncidents = @differentialIncidents.get()
    # Toggle the incident type if there are no matching incidents
    if not _.findWhere(differentialIncidents, type: incidentType)
      if differentialIncidents.length >= 1
        if incidentType == 'cases'
          @incidentType.set('deaths')
        else
          @incidentType.set('cases')
        return
    @loading.set(true)
    @highlightedLocations.remove({})
    differentials = _.where(differentialIncidents, type: incidentType)
    subIntervals = differentailIncidentsToSubIntervals(differentials)
    if subIntervals.length > Constants.MAX_SUBINTERVALS
      @tooManyIncidents.set(true)
      @loading.set(false)
      return
    else
      @tooManyIncidents.set(false)
    _.delay =>
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

      @autorun =>
        renderPlot(differentials, locToSubintervals, locationTree, topLocations)
        @loading.set(false)

Template.eventResolvedIncidents.helpers
  tooManyIncidents: ->
    Template.instance().tooManyIncidents.get()

  activeMode: (value) ->
    instance = Template.instance()
    if instance.incidentType.get() == 'deaths'
      if instance.plotType.get() == 'rate'
        if value == 'deathRate'
          return 'active'
      else
        if value == 'deaths'
          return 'active'
    else
      if instance.plotType.get() == 'rate'
        if value == 'caseRate'
          return 'active'
      else
        if value == 'cases'
          return 'active'

  labels: ->
    Template.instance().legend.get()

  isLoading: ->
    Template.instance().loading.get()

  disableCases: ->
    not _.findWhere(Template.instance().differentialIncidents.get(),
      type: 'cases'
    )

  disableDeaths: ->
    not _.findWhere(Template.instance().differentialIncidents.get(),
      type: 'deaths'
    )

Template.eventResolvedIncidents.events
  "click .incident-type-selector .cases": (event, instance) ->
    instance.incidentType.set("cases")
    instance.plotType.set("cumulative")

  "click .incident-type-selector .deaths": (event, instance) ->
    instance.incidentType.set("deaths")
    instance.plotType.set("cumulative")

  "click .incident-type-selector .case-rate": (event, instance) ->
    instance.incidentType.set("cases")
    instance.plotType.set("rate")

  "click .incident-type-selector .death-rate": (event, instance) ->
    instance.incidentType.set("deaths")
    instance.plotType.set("rate")

  "click .rickshaw_graph": (event, instance) ->
    if instance.hoveredIntervalClickEvent
      instance.hoveredIntervalClickEvent(event, instance)

  "click .legend label": (event, instance) ->
    if instance.highlightedLocations.findOne(@id)
      instance.highlightedLocations.remove(@id)
    else
      instance.highlightedLocations.insert(_id: @id)
