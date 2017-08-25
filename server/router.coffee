import UserEvents from '/imports/collections/userEvents'
import Articles from '/imports/collections/articles'
import Incidents from '/imports/collections/incidentReports'
import utils from '/imports/utils'
import PromedPosts from '/imports/collections/promedPosts'
import convertAllIncidentsToDifferentials from '/imports/incidentResolution/convertAllIncidentsToDifferentials'
import {
  differentailIncidentsToSubIntervals,
  extendSubIntervalsWithValues
} from '/imports/incidentResolution/incidentResolution'

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
    incidents = utils.createIncidentReportsFromEnhancements enhancements,
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
Router.route("/api/resolve-incidents", {where: "server"})
.post ->
  differentials = convertAllIncidentsToDifferentials(@request.body)
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
