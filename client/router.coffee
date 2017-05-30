Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'

redirectIfNotAuthorized = (router, roles) ->
  unless Meteor.userId() and roles.length
    router.redirect '/sign-in'
    return

  unless Roles.userIsInRole(Meteor.userId(), roles)
    if Meteor.userId()
      router.redirect '/'
    else
      router.redirect '/sign-in'
  router.next()

Router.configure
  layoutTemplate: "layout"
  loadingTemplate: "loading"

Router.onBeforeAction ->
  routeTitle = @route.options.title
  title = 'EIDR-Connect'
  if _.isString(routeTitle)
    title += ": #{routeTitle}"
  else if _.isFunction(routeTitle)
    title += ": #{routeTitle.call(@)}"
  document.title = title
  @next()

Router.onAfterAction ->
  window.scroll 0, 0

Router.route "/",
  name: 'splash'

Router.route "/about",
  title: 'About'

Router.route "/event-map",
  name: 'event-map'
  title: 'Event Map'

Router.route "/admins",
  name: 'admins'
  title: 'Manage User Accounts'
  onBeforeAction: ->
    redirectIfNotAuthorized(@, ['admin'])
  waitOn: ->
    Meteor.subscribe "allUsers"
  data: ->
    adminUsers: Meteor.users.find({ roles: {$in: ["admin"]} }, {sort: {'profile.name': 1}})
    curatorUsers: Meteor.users.find({ roles: {$in: ["curator"] }}, {sort: {'profile.name': 1}})
    defaultUsers: Meteor.users.find({ roles: {$not: {$in: ["admin", "curator"]} }}, {sort: {'profile.name': 1}})

Router.route "/download",
  name: 'download'
  title: 'Download'
  onBeforeAction: ->
    redirectIfNotAuthorized(@, [])

  action: ->
    @render('preparingDownload')
    controller = @
    Meteor.call 'download', (err, result) ->
      unless err
        csvData = "data:text/csv;charset=utf-8," + result.csv
        jsonData = "data:application/json;charset=utf-8," + result.json
        controller.render 'download',
          data:
            jsonData: encodeURI(jsonData)
            csvData: encodeURI(csvData)

Router.route "/contact-us",
  name: 'contact-us'
  title: 'Contact Us'

Router.route "/events",
  name: 'eventIndex'
  title: 'Events'
  onBeforeAction: ->
    Router.go 'events', _view: 'curated'

Router.route "/events/:_view",
  name: 'events'
  title: 'Events'

Router.route "/curator-inbox",
  name: 'curator-inbox'
  title: 'Curator Inbox'
  waitOn: ->
    Meteor.subscribe "userEvents"
  onBeforeAction: ->
    redirectIfNotAuthorized(@, ['admin', 'curator'])

Router.route "/events/curated-events/:_id/:_view?",
  name: 'curated-event'
  data: ->
    view: @params._view
    userEventId: @params._id

Router.route "/events/smart-events/:_id/:_view?",
  name: 'smart-event'

Router.route "/feeds",
  onBeforeAction: ->
    redirectIfNotAuthorized(@, ['admin'])
  name: 'feeds'
  title: 'Feeds'

Router.route "/extract-incidents",
  name: 'extractIncidents'
  layoutTemplate: "extractIncidentsLayout"
