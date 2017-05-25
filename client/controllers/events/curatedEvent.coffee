Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
#Allow multiple modals or the suggested locations list won't show after the loading modal is hidden
Modal.allowMultiple = true

Template.curatedEvent.onCreated ->
  @editState = new ReactiveVar(false)
  @loaded = new ReactiveVar(false)
  userEventId = @data.userEventId
  @subscribe "userEvent", @data.userEventId, =>
    userEvent = UserEvents.findOne(userEventId)
    document.title += ": #{userEvent.eventName}"
    incidentIds = _.map userEvent.incidents, (incident) ->
      incident.id
    @subscribe "eventArticles", userEventId
    @subscribe 'eventIncidents', incidentIds, =>
      @loaded.set(true)

Template.curatedEvent.onRendered ->
  new Clipboard '.copy-link'

Template.curatedEvent.helpers
  userEvent: ->
    UserEvents.findOne(Template.instance().data.userEventId)

  eventHasArticles: ->
    Articles.find().count()

  articleData: ->
    articles: Articles.find()
    userEvent: UserEvents.findOne(Template.instance().data.userEventId)

  incidents: ->
    Incidents.find()

  isEditing: ->
    Template.instance().editState.get()

  incidentView: ->
    viewParam = Router.current().getParams()._view
    typeof viewParam is 'undefined' or viewParam is 'incidents'

  locationView: ->
    Router.current().getParams()._view is 'locations'

  deleted: ->
    UserEvents.findOne(Template.instance().data.userEventId)?.deleted

  view: ->
    currentView = Router.current().getParams()._view
    if currentView is 'locations'
      return 'locationList'
    'incidentReports'

  templateData: ->
    userEvent: UserEvents.findOne(Template.instance().data.userEventId)
    articles: Articles.find()
    incidents: Incidents.find()

  loaded: ->
    Template.instance().loaded.get()

Template.curatedEvent.events
  'click .edit-link, click #cancel-edit': (event, instance) ->
    instance.editState.set(not instance.editState.get())

  'click .open-incident-form-in-details': (event, instance) ->
    data = instance.data
    Modal.show 'incidentModal',
      articles: data.articles
      userEventId: data.userEvent._id
      add: true

  'click .open-source-form-in-details': (event, instance) ->
    Modal.show('sourceModal', userEventId: instance.data.userEvent._id)

  'click .tabs li a': (event) ->
    event.currentTarget.blur()
