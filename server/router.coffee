import UserEvents from '/imports/collections/userEvents'
import AutoEvents from '/imports/collections/autoEvents'
import Articles from '/imports/collections/articles'
import Incidents from '/imports/collections/incidentReports'
import utils from '/imports/utils'
import { createIncidentReportsFromEnhancements } from '/imports/nlp'
import PromedPosts from '/imports/collections/promedPosts'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials'
import {
  differentailIncidentsToSubIntervals,
  extendSubIntervalsWithValues
} from '/imports/incidentResolution/incidentResolution'
import LocationTree from '/imports/incidentResolution/LocationTree'


fs = Npm.require('fs')
path = Npm.require('path')

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
  @response.end(EJSON.stringify(UserEvents.find({}, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/auto-events", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  @response.end(EJSON.stringify(AutoEvents.find({}, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/incidents", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  @response.end(EJSON.stringify(Incidents.find({}, {
    skip: parseInt(@request.query.skip or 0)
    limit: parseInt(@request.query.limit or 100)
  }).fetch()))

Router.route("/api/articles", {where: "server"})
.get ->
  @response.setHeader('Content-Type', 'application/ejson')
  @response.statusCode = 200
  @response.end(EJSON.stringify(Articles.find({}, {
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
  console.log sanitizedUrl, events.length
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
  subIntervals = differentailIncidentsToSubIntervals(differentials)
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
  events.forEach (event) ->
    if event.incidents
      query =
        _id: $in: _.pluck(event.incidents, 'id')
        accepted: $in: [null, true]
        deleted: $in: [null, false]
        locations: $not: $size: 0
    else
      query = utils.eventToIncidentQuery(event)
    if dateRange
      query['dateRange.start'] = $lte: dateRange.end
      query['dateRange.end'] = $gte: dateRange.start
    event.incidents = Incidents.find(query).fetch()
  @response.setHeader('Access-Control-Allow-Origin', '*')
  @response.setHeader('Content-Type', 'application/json')
  @response.statusCode = 200
  @response.end(JSON.stringify({
    events: events.map (event) ->
      differentials = _.where(
        convertAllIncidentsToDifferentials(event.incidents),
        type: 'cases'
      )
      subIntervals = differentailIncidentsToSubIntervals(differentials)
      extendSubIntervalsWithValues(differentials, subIntervals)
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
      countryCodeToCount = {}
      maxSubintervalsPerLocation = []
      _.pairs(locToSubintervals).map ([key, locSubIntervals]) ->
        location = locationTree.getLocationById(key)
        groupedLocSubIntervals = _.groupBy(locSubIntervals, 'start')
        maxSubintervals = []
        for group, subIntervalGroup of groupedLocSubIntervals
          maxSubintervals.push(_.max(subIntervalGroup, (x) -> x.value))
        maxSubintervalsPerLocation = maxSubintervalsPerLocation.concat(maxSubintervals)
        maxSubintervals = _.sortBy(maxSubintervals, (x) -> x.start)
        total = 0
        maxSubintervals.forEach (subInt) ->
          # Prorate the count if it is outside of the dateRange
          if dateRange and (subInt.end > dateRange.end or subInt.start < dateRange.start)
            [noop, overlapStart, overlapEnd, noop2] = [
              subInt.end, subInt.start, Number(dateRange.start), Number(dateRange.end)
            ].sort()
            overlapRatio = (overlapEnd - overlapStart) / (subInt.end - subInt.start)
            total += subInt.value * overlapRatio
          else
            total += subInt.value
        # If the country code appeared before, it is because the top locations
        # are not at the country level, so values with the same country code
        # can be combined to get the count for the country.
        prevTotal = countryCodeToCount[location.countryCode] or 0
        countryCodeToCount[location.countryCode] = prevTotal + total
      groupedSubIntervals = _.groupBy(maxSubintervalsPerLocation, 'end')
      overallTimeseries = _.chain(groupedSubIntervals)
        .pairs()
        .map ([end, group]) ->
          date: new Date(parseInt(end))
          value: group.reduce(((sofar, cur)-> sofar + cur.value), 0)
        .sortBy('date')
        .value()
      return {
        eventId: event._id
        eventName: event.eventName
        locations: countryCodeToCount
        timeseries: overallTimeseries
      }
  }))
