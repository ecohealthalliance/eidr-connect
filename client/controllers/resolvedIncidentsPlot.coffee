import Highcharts from 'highcharts'
import solverExport from 'javascript-lp-solver'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials.coffee'
import {
  differentailIncidentsToSubIntervals,
  subIntervalsToLP
} from '/imports/incidentResolution/incidentResolution.coffee'
import LocationTree from '/imports/incidentResolution/LocationTree.coffee'

Template.resolvedIncidentsPlot.onCreated ->
  @incidents = @data.incidents
  @incidentType = new ReactiveVar("deaths")

Template.resolvedIncidentsPlot.onRendered ->
  @autorun =>
    allIncidents = @incidents.fetch()
    incidentType = @incidentType.get()
    allIncidents = allIncidents.filter (i)->
      i.locations.every (l)-> l.featureCode
    differentials = convertAllIncidentsToDifferentials(allIncidents)
    deathDifferentials = _.where(differentials, type: incidentType)
    subIntervals = differentailIncidentsToSubIntervals(deathDifferentials)
    subIntervals.forEach (s)->
      s.value = 0
    model = subIntervalsToLP(deathDifferentials, subIntervals)
    solution = solver.Solve(solver.ReformatLP(model))
    for key, value of solution
      if key.startsWith("s")
        subId = key.split("s")[1]
        subInterval = subIntervals[parseInt(subId)]
        subInterval.value = value
    for subInterval in subIntervals
      subInterval.incidents = subInterval.incidentIds.map (id)-> deathDifferentials[id]
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
    Highcharts.chart(@$(".container")[0], {
      chart:
        type: 'area'
        zoomType: 'x'
        panning: true
        panKey: 'shift'
      title:
        text: if incidentType == "cases" then 'Case Rate' else 'Death Rate'
      subtitle:
        text: 'Rates are derived from incident report data'
      xAxis:
        type: 'datetime'
        dateTimeLabelFormats:
        	day: '%b %e'
        	week: '%b %e'
        	month: '%b \'%y'
        	year: '%Y'
        title:
          text: 'Date'
      yAxis:
        title:
          text: 'Number Per Day'
        min: 0
      tooltip:
        shared: true
        headerFormat: '<b>{series.name}</b><br>'
        pointFormat: '{point.x:%Y-%m-%d}: {point.y:.2f}'
      series: _.map locToSubintervals, (locSubIntervals, key)->
        location = locationTree.getLocationById(key)
        groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
        maxSubintervals = []
        for group, subIntervalGroup of groupedLocSubIntervals
          maxSubintervals.push(_.max(subIntervalGroup, (x)-> x.value))
        maxSubintervals = _.sortBy(maxSubintervals, (x)-> x.start)

        findNearestPointBy: 'xy'
        name: location.name
        cursor: 'pointer'
        point:
          events:
            click: (e)->
              concurrentIntervals = groupedLocSubIntervals[@interval.start] or []
              Modal.show('intervalDetailsModal',
                interval: @interval
                concurrentIntervals: concurrentIntervals
                incidents: @interval.incidentIds.map (id)->
                  deathDifferentials[id]
              )
        data: _.chain(_.zip(maxSubintervals, maxSubintervals.slice(1)))
          .map(([i, iNext])->
            rate = i.value / ((i.end - i.start) / 1000 / 60 / 60 / 24)
            result = [
              {x: i.start, y: rate, interval: i}
              {x: i.end, y: rate, interval: i}
            ]
            if iNext and i.end != iNext.start
              result.push [i.end, 0]
              result.push [iNext.start, 0]
            result
          )
          .reduce((sofar, cur)->
            prev = sofar.slice(0)[1]
            if prev and prev[0] == cur[0]
              cur[0] += 10
              sofar.concat([cur])
            else
              sofar.concat([cur])
          , [])
          .flatten(true)
          .value()
    })

Template.resolvedIncidentsPlot.helpers
  deathsActive: ->
    if Template.instance().incidentType.get() == "deaths"
      "active"

  casesActive: ->
    if Template.instance().incidentType.get() == "cases"
      "active"

Template.resolvedIncidentsPlot.events
  "click .incident-type-selector .cases": (e, instance)->
    instance.incidentType.set("cases")

  "click .incident-type-selector .deaths": (e, instance)->
    instance.incidentType.set("deaths")
