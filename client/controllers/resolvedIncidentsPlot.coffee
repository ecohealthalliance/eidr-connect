import Rickshaw from 'meteor/eidr:rickshaw.min'
import solverExport from 'javascript-lp-solver'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials.coffee'
import {
  differentailIncidentsToSubIntervals,
  subIntervalsToLP
} from '/imports/incidentResolution/incidentResolution.coffee'
import LocationTree from '/imports/incidentResolution/LocationTree.coffee'

Template.resolvedIncidentsPlot.onCreated ->
  @incidents = @data.incidents
  @incidentType = new ReactiveVar("cases")
  @legend = new ReactiveVar([])
  @loading = new ReactiveVar(false)

Template.resolvedIncidentsPlot.onRendered ->
  @autorun =>
    @hoveredIntervalClickEvent = null
    allIncidents = @incidents.fetch()
    incidentType = @incidentType.get()
    @loading.set(true)
    _.delay =>
      allIncidents = allIncidents.filter (i)->
        i.locations.every (l)-> l.featureCode
      differentials = convertAllIncidentsToDifferentials(allIncidents)
      differentials = _.where(differentials, type: incidentType)
      subIntervals = differentailIncidentsToSubIntervals(differentials)
      subIntervals.forEach (s)->
        s.value = 0
      model = subIntervalsToLP(differentials, subIntervals)
      solution = solver.Solve(solver.ReformatLP(model))
      for key, value of solution
        if key.startsWith("s")
          subId = key.split("s")[1]
          subInterval = subIntervals[parseInt(subId)]
          subInterval.value = value
      for subInterval in subIntervals
        subInterval.incidents = subInterval.incidentIds.map (id)-> differentials[id]
      locationTree = LocationTree.from(subIntervals.map (x)->x.location)
      topLocations = locationTree.children.map (x)->x.value
      locToSubintervals = {}
      for topLocation in topLocations
        locToSubintervals[topLocation.id] = []
      for topLocation in topLocations
        for subInterval in subIntervals
          loc = subInterval.location
          if LocationTree.locationContains(topLocation, loc)
            locToSubintervals[topLocation.id].push(subInterval)
      @$('.chart').html('''<div class="y-axis"></div>
        <div class="graph"></div>
        <div class="slider"></div>
        <div class="legend"></div>''')
      palette = new Rickshaw.Color.Palette(
        scheme: 'colorwheel'
        interpolatedStopCount: topLocations.length
      )
      pairedLocs = _.pairs(locToSubintervals)
      @legend.set(pairedLocs.map ([key], sIdx)->
        name: locationTree.getLocationById(key).name
        color: palette.color(sIdx)
      )
      graph = new Rickshaw.Graph({
        element: @$('.graph')[0]
        renderer: 'multi'
        stack: false
        interpolation: 'linear'
        dotSize: 5
        strokeWidth: 2
        series: pairedLocs.map ([key, locSubIntervals], sIdx)->
          location = locationTree.getLocationById(key)
          groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
          maxSubintervals = []
          for group, subIntervalGroup of groupedLocSubIntervals
            maxSubintervals.push(_.max(subIntervalGroup, (x)-> x.value))
          maxSubintervals = _.sortBy(maxSubintervals, (x)-> x.start)
          return {
            name: location.name
            color: palette.color(sIdx)
            renderer: 'line'
            data: _.chain(_.zip(maxSubintervals, maxSubintervals.slice(1)))
              .map(([subInt, iNext])->
                onClick = ->
                  concurrentIntervals = groupedLocSubIntervals[subInt.start] or []
                  componentTree = LocationTree.from(concurrentIntervals.map (x)-> x.location)
                  concurrentIntervals.forEach (x)->
                    componentTree.getNodeById(x.location.id).associatedObject = x
                  Modal.show('intervalDetailsModal',
                    interval: subInt
                    componentTree: componentTree
                    incidents: subInt.incidentIds.map (id)->
                      differentials[id]
                  )
                rate = subInt.value / ((subInt.end - subInt.start) / 1000 / 60 / 60 / 24)
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
              .reduce((sofar, cur)->
                prev = sofar.slice(0)[1]
                if prev and prev.x == cur.x
                  cur.x += 1
                  sofar.concat([cur])
                else
                  sofar.concat([cur])
              , [])
              .value()
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
        formatter: (series, x, y, formattedX, formattedY, obj)=>
          @hoveredIntervalClickEvent = obj.value.onClick
          "#{series.name}: #{y.toFixed(2)} cases per day"
      )
      graph.render()
      @loading.set false
    , 300

Template.resolvedIncidentsPlot.helpers
  deathsActive: ->
    if Template.instance().incidentType.get() == "deaths"
      "active"

  casesActive: ->
    if Template.instance().incidentType.get() == "cases"
      "active"

  labels: ->
    Template.instance().legend.get()

  isLoading: ->
    Template.instance().loading.get()

Template.resolvedIncidentsPlot.events
  "click .incident-type-selector .cases": (e, instance)->
    instance.incidentType.set("cases")

  "click .incident-type-selector .deaths": (e, instance)->
    instance.incidentType.set("deaths")

  "click .rickshaw_graph": (e, instance)->
    if instance.hoveredIntervalClickEvent
      instance.hoveredIntervalClickEvent(e, instance)
