import UserEvents from '/imports/collections/userEvents'
import AutoEvents from '/imports/collections/autoEvents'
import Articles from '/imports/collections/articles'
import Incidents from '/imports/collections/incidentReports'
import utils from '/imports/utils'
import { createIncidentReportsFromEnhancements } from '/imports/nlp'
import PromedPosts from '/imports/collections/promedPosts'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials'
import {
  differentialIncidentsToSubIntervals,
  removeOutlierIncidents,
  createSupplementalIncidents,
  extendSubIntervalsWithValues,
  subIntervalsToActiveCases
} from '/imports/incidentResolution/incidentResolution'
import LocationTree from '/imports/incidentResolution/LocationTree'
import { _ } from 'meteor/underscore';

fs = Npm.require('fs')
path = Npm.require('path')

ENABLE_PROFILING = false

Router.configureBodyParsers = ->
  # The resolve-incidents endpoint may have files larger than the default limit
  # sent to it.
  @onBeforeAction(Iron.Router.bodyParser.json({
    limit: '50mb'
  }))

Router.route("/revision", {where: "server"})
.get ->
  fs.readFile path.join(process.env.PWD, 'revision.txt'), 'utf8', (err, data)=>
    if err
      console.log(err)
      @response.end("Error getting revision. Check the server log for details.")
    else
      @response.end(data)

Router.route("/api/events", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  query = {}
  if @request.query?.query
    query = JSON.parse(@request.query.query)
  @response.end(EJSON.stringify(UserEvents.find(query, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/auto-events", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  query = {}
  if @request.query?.query
    query = JSON.parse(@request.query.query)
  @response.end(EJSON.stringify(AutoEvents.find(query, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/incidents", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  query = {}
  if @request.query?.query
    query = JSON.parse(@request.query.query)
  @response.end(EJSON.stringify(Incidents.find(query, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/articles", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  query = {}
  if @request.query?.query
    query = JSON.parse(@request.query.query)
  @response.end(EJSON.stringify(Articles.find(query, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/events-incidents-articles", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  @response.end(EJSON.stringify(UserEvents.find({}, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 10)
  }).map (event) ->
    event._incidents = Incidents.find(
      _id:
        $in: _.pluck(event.incidents, 'id')
    ).fetch()
    event._articles = Articles.find(
      $or: [
        {_id: $in: _.pluck(event._incidents, 'articleId')}
        {userEventIds: event._id}
      ]
    ).fetch()
    event
  ))

Router.route("/api/event-search/:name", {where: "server"})
.get ->
  pattern = '.*' + @params.name + '.*'
  regex = new RegExp(pattern, 'g')
  mongoProjection = {
    eventName: {
      $regex: regex,
      $options: 'i'
    }
    deleted: {$in: [null, false]}
  }
  matchingEvents = UserEvents.find(mongoProjection, {sort: {eventName: 1}}).fetch()
 
  @response.setHeader('Access-Control-Allow-Origin', '*')
  @response.statusCode = 200
  @response.end(JSON.stringify(matchingEvents))

Router.route("/api/event-article", {where: "server"})
.post ->
  userEventId = @request.body.eventId ? ""
  article = @request.body.articleUrl ? ""
  
  if userEventId.length and article.length
    userEvent = getUserEvents().findOne(userEventId)
    if userEvent
      existingArticle = Articles.find({url: article, userEventIds: userEventId}).fetch()
      
      if existingArticle.length is 0
        Articles.insert({userEventIds: [userEventId], url: article})
  
  @response.setHeader('Access-Control-Allow-Origin', '*')
  @response.statusCode = 200
  @response.end("")

Router.route("/api/events-with-source", {where: "server"})
.get ->
  sanitizedUrl = @request.query.url.replace(/^https?:\/\//, "").replace(/^www\./, "")
  articles = Articles.find(
    url:
      $regex: utils.regexEscape(sanitizedUrl) + "$"
    deleted:
      $in: [null, false]
  ).fetch()
  events = UserEvents.find(
    _id:
      $in: _.pluck(articles, 'userEventId')
    deleted:
      $in: [null, false]
    displayOnPromed: true
  ).map (event)->
    event.articles = Articles.find(
      userEventId: event._id
    ).fetch()
    event
  #console.log sanitizedUrl, events.length
  @response.setHeader('Access-Control-Allow-Origin', '*')
  @response.statusCode = 200
  @response.end(JSON.stringify(events))

###
@api {get} process-document Generate GRITS api enhancements and EIDR-C incidents
                            for the ProMED post with the given id.
@apiParam {String} promedId
###
Router.route("/api/process-document", {where: "server"})
.get ->
  promedId = @request.query.promedId
  post = PromedPosts.findOne
    promedId: promedId
  Meteor.call 'getArticleEnhancements', {
    content: post.content
    publishDate: post.promedDate
  }, (error, enhancements) =>
    if error
      @response.statusCode = 400
      return @response.end(JSON.stringify(error))
    incidents = createIncidentReportsFromEnhancements enhancements,
      acceptByDefault: true
    @response.setHeader('Access-Control-Allow-Origin', '*')
    @response.statusCode = 200
    @response.end(JSON.stringify(
      enhancements: enhancements
      incidents: incidents
    ))

###
@api {post} resolve-incidents Resolve a set of potentially overlapping incidents into
                              single case or death count values over each location and time interval.
@apiParamExample {json} Request-Example:
    [
      {
        "deaths": 1,
        "locations": [{
          "id": "6255146",
          "name": "Africa",
          "admin1Name": null,
          "admin2Name": null,
          "latitude": 7.1881,
          "longitude": 21.09375,
          "countryName": null,
          "population": 1031833000,
          "featureClass": "L",
          "featureCode": "CONT"
        }],
        "dateRange": {
          "start": "2014-04-09T00:00:00.000Z",
          "end": "2014-04-09T23:59:59.999Z"
        }
      }
    ]
@apiSuccessExample {json} Success-Response:
    [
      {
        "start": "2014-04-09T00:00:00.000Z",
        "end": "2014-04-10T00:00:00.000Z",
        "location": {
          "id": "6255146",
          "name": "Africa",
          "admin1Name": null,
          "admin2Name": null,
          "latitude": 7.1881,
          "longitude": 21.09375,
          "countryName": null,
          "population": 1031833000,
          "featureClass": "L",
          "featureCode": "CONT"
        },
        "incidentIds": [0],
        "value": 1
      }
    ]
###
Router.route("/api/resolve-incidents", where: "server")
.post ->
  try
    differentials = convertAllIncidentsToDifferentials(@request.body)
  catch e
    @response.statusCode = 400
    return @response.end("Invalid incidents: " + e)
  # Require a single type of incident
  if _.findWhere(differentials, type: 'cases') and _.findWhere(differentials, type: 'deaths')
    @response.statusCode = 400
    return @response.end("The submitted incidents must all be of a single type, either case counts or death counts.")
  subIntervals = differentialIncidentsToSubIntervals(differentials)
  extendSubIntervalsWithValues(differentials, subIntervals)
  @response.setHeader('Access-Control-Allow-Origin', '*')
  @response.statusCode = 200
  @response.end(JSON.stringify(subIntervals.map((s) ->
    start: new Date(s.start)
    end: new Date(s.end)
    location: _.omit(s.location, 'alternateNames')
    incidentIds: s.incidentIds
    value: s.value
  )))

###
@api {post} events-with-resolved-data Return the resolved cases for a set of
  events specified by id. The resolved cases are broken down by time and location.
@apiParam {string} eventType="user" Whether the event ids correspond to user curated events or auto events.
@apiParam {boolean} fullLocations=false Whether to include lower-level location information or just resolved cases by country.
@apiParam {ISODateString} startDate The date range of incident to resolve.
@apiParam {ISODateString} endDate The date range of incident to resolve.
@apiSuccessExample {json} Success-Response:
  {
    eventId: {
      "locations": {
        CountryCode: Number
      },
      "timseries": [
        {
          "date": ISODate,
          "value": Number
        }
      ]
    }
  }
###
Router.route("/api/events-with-resolved-data", where: "server")
.get ->
  eventIds = @request.query.ids
  if _.isString(@request.query.ids)
    eventIds = [@request.query.ids]
  if @request.query.startDate
    dateRange =
      start: new Date(@request.query.startDate)
      end: new Date(@request.query.endDate)
  if @request.query.eventType == 'user'
    events = UserEvents.find(
      _id:
        $in: eventIds
      deleted:
        $in: [null, false]
    ).fetch()
  else if @request.query.eventType == 'auto'
    events = AutoEvents.find(
      _id:
        $in: eventIds
      deleted:
        $in: [null, false]
    ).fetch()
  # sort events so they are returned in same order as the ids
  events = eventIds.map (eventId)->
    _.findWhere(events, _id: eventId)
  events.forEach (event) =>
    if not event
      return
    if event.incidents
      query =
        _id: $in: _.pluck(event.incidents, 'id')
        accepted: $in: [null, true]
        deleted: $in: [null, false]
        locations: $not: $size: 0
    else
      query = utils.eventToIncidentQuery(event)
    if dateRange
      if (@request.query.activeCases + "").toLowerCase() == "true"
        # TODO: look up disease specific stat
        event.caseLengthDays = 14
        extendedStartDate = new Date(dateRange.start)
        # Incidents from an extended date range are included to determine the
        # initial number of active cases at the beginning of the intended date range.
        # Assuming the half life of all cases is the case length, less than 10%
        # of the cases from before the extended date range would still be active
        # in the original date range.
        extendedStartDate.setUTCDate(extendedStartDate.getUTCDate() - (4 * event.caseLengthDays))
        dateRange.start = extendedStartDate
      # The query will return incidents that only partially overlap the date range.
      # The resolved date range is used to truncate those incidents to only include
      # the overlapping date range.
      event.resolvedDateRange = dateRange
      query['dateRange.start'] = $lt: dateRange.end
      query['dateRange.end'] = $gt: dateRange.start
    console.time('fetch incidents') if ENABLE_PROFILING
    event.incidents = Incidents.find(query).fetch()
    console.timeEnd('fetch incidents') if ENABLE_PROFILING
  @response.setHeader('Access-Control-Allow-Origin', '*')
  @response.setHeader('Content-Type', 'application/json')
  @response.statusCode = 200
  @response.end(JSON.stringify({
    events: events.map (event) =>
      if not event
        return null
      dailyDecayRate = 1.0
      if (@request.query.activeCases + "").toLowerCase() == "true"
        dailyDecayRate = Math.pow(.5, (1 / event.caseLengthDays))
      console.time('create differentials') if ENABLE_PROFILING
      baseIncidents = []
      constrainingIncidents = []
      event.incidents.map (incident) ->
        if incident.constraining
          constrainingIncidents.push incident
        else
          baseIncidents.push incident
      incidentsWithoutOutliers = removeOutlierIncidents(
        baseIncidents,
        constrainingIncidents
      )
      supplementalIncidents = createSupplementalIncidents(
        incidentsWithoutOutliers,
        constrainingIncidents
      )
      allDifferentials = convertAllIncidentsToDifferentials(
        incidentsWithoutOutliers
      ).concat(supplementalIncidents)
      differentials = _.where(allDifferentials, type: 'cases').map (differential) ->
        if event.resolvedDateRange
          differential = differential.truncated(event.resolvedDateRange)
        differential
      subIntervals = differentialIncidentsToSubIntervals(differentials)
      console.timeEnd('create differentials') if ENABLE_PROFILING
      console.time('resolve') if ENABLE_PROFILING
      extendSubIntervalsWithValues(differentials, subIntervals)
      console.timeEnd('resolve') if ENABLE_PROFILING
      locationTree = LocationTree.from(subIntervals.map (x) -> x.location)
      topLocations = locationTree.children.map (x) -> x.value
      locToSubintervals = {}
      for location in locationTree.locations()
        locToSubintervals[location.id] = []
      for location in locationTree.locations()
        for subInterval in subIntervals
          subLocation = subInterval.location
          if LocationTree.locationContains(location, subLocation)
            locToSubintervals[location.id].push(subInterval)
      maxSubintervalsPerTopLocation = []
      locationToTotals = _.chain(locToSubintervals)
      .pairs()
      .map ([key, locSubIntervals]) =>
        location = locationTree.getLocationById(key)
        groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
        maxSubintervals = []
        for group, subIntervalGroup of groupedLocSubIntervals
          subIntervalGroupTree = LocationTree.from(subIntervalGroup.map (x) -> x.location)
          subIntervalGroupTree.children.forEach (locationNode) ->
            maxSubintervals.push(_.max(subIntervalGroup, (subInterval) ->
              if locationNode.value.id == subInterval.location.id
                subInterval.value
              else
                0
            ))
        if location in topLocations
          maxSubintervalsPerTopLocation = maxSubintervalsPerTopLocation.concat(maxSubintervals)
        maxSubintervals = _.sortBy(maxSubintervals, (x) -> x.start)
        console.time('compute active cases') if ENABLE_PROFILING
        total = subIntervalsToActiveCases(maxSubintervals, dailyDecayRate).slice(-1)[0][1]
        console.timeEnd('compute active cases') if ENABLE_PROFILING
        return [key, total]
      .object()
      .value()
      countryCodeToCount = {}
      for topLocation in topLocations
        # If the country code appeared before, it is because the top locations
        # are not at the country level, so values with the same country code
        # can be combined to get the count for the country.
        prevTotal = countryCodeToCount[topLocation.countryCode] or 0
        countryCodeToCount[topLocation.countryCode] = prevTotal + locationToTotals[topLocation.id]

      if (@request.query.activeCases + "").toLowerCase() == "true"
        startDate = new Date(@request.query.startDate)
        console.time('compute active cases for overall timeseries') if ENABLE_PROFILING
        overallTimeseries = subIntervalsToActiveCases(
          maxSubintervalsPerTopLocation,
          dailyDecayRate
        ).filter ([date, rate]) => date >= startDate
        console.timeEnd('compute active cases for overall timeseries') if ENABLE_PROFILING
      else
        overallTimeseries = _.chain(maxSubintervalsPerTopLocation)
          .groupBy('end')
          .pairs()
          .map ([end, group]) -> [new Date(parseInt(end)), group]
          .sortBy (x) -> x[0]
          .reduce((sofar, [endDate, group]) ->
            value = group.reduce(((sofar, cur) -> sofar + cur.rate), 0)
            if sofar
              sofar.concat(
                date: endDate
                value: value
              )
            else
              [
                date: new Date(group[0].start)
                value: value
              ,
                date: endDate
                value: value
              ]
          , null)
          .value()
      result = {
        eventId: event._id
        eventName: event.eventName
        timeseries: overallTimeseries
      }
      if (@request.query.fullLocations + "").toLowerCase() == "true"
        result.fullLocations = locationTree.toJSON ({value, children}) ->
          return {
            location: value
            value: locationToTotals[value.id]
            children: children.filter (child) -> child.value > 0
          }
      else
        result.locations = countryCodeToCount
      return result
  }))
