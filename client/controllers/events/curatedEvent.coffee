Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
#Allow multiple modals or the suggested locations list won't show after the loading modal is hidden
Modal.allowMultiple = true

Template.curatedEvent.onCreated ->
  @editState = new ReactiveVar(false)
  @loaded = new ReactiveVar(false)
  userEventId = @data.userEventId
  @subscribe "userEvent", @data.userEventId

  @autorun =>
    userEvent = UserEvents.findOne(userEventId)
    if userEvent
      document.title = "Eidr-Connect: #{userEvent.eventName}"

  @subscribe "eventArticles", userEventId
  @subscribe 'eventIncidents', userEventId, =>
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
    event = UserEvents.findOne(Template.instance().data.userEventId)
    Incidents.find(_id: $in: _.pluck(event.incidents, 'id'))

  incidentCount: ->
    Incidents.find().count()

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
    instance = Template.instance()

    userEvent = UserEvents.findOne(instance.data.userEventId)
    userEvent: userEvent
    articles: Articles.find()
    incidents: Incidents.find(_id: $in: _.pluck(userEvent.incidents, 'id'))

  loaded: ->
    Template.instance().loaded.get()

  documentCount: ->
    Articles.find().count()

Template.curatedEvent.events
  'click .edit-link, click #cancel-edit': (event, instance) ->
    instance.editState.set(not instance.editState.get())

  'click .open-incident-form-in-details': (event, instance) ->
    Modal.show 'incidentModal',
      articles: Articles.find()
      userEventId: instance.data.userEventId
      add: true

  'click .open-source-form-in-details': (event, instance) ->
    Modal.show('sourceModal', userEventId: instance.userEventId)

  'click .tabs li a': (event) ->
    event.currentTarget.blur()
