EventIncidents = require '/imports/collections/eventIncidents'
EventArticles = require '/imports/collections/eventArticles'
UserEvents = require '/imports/collections/userEvents'

#Allow multiple modals or the suggested locations list won't show after the loading modal is hidden
Modal.allowMultiple = true

Template.curatedEvent.onCreated ->
  @loaded = new ReactiveVar(false)
  userEventId = @data.userEventId
  @selectedView = new ReactiveVar('resolvedIncidentsPlot')

  @subscribe 'userEvent', @data.userEventId, =>
    @loaded.set(true)

  @autorun =>
    userEvent = UserEvents.findOne(userEventId)
    if userEvent
      document.title = "Eidr-Connect: #{userEvent.eventName}"

Template.curatedEvent.onRendered ->
  new Clipboard '.copy-link'

Template.curatedEvent.helpers
  userEvent: ->
    UserEvents.findOne(Template.instance().data.userEventId)

  eventHasArticles: ->
    EventArticles.find().count()

  articleData: ->
    instance = Template.instance()

    articles: EventArticles.find()
    userEvent: UserEvents.findOne(instance.data.userEventId)

  incidents: ->
    EventIncidents.find()

  incidentCount: ->
    EventIncidents.find().count()

  incidentView: ->
    viewParam = Router.current().getParams()._view
    typeof viewParam is 'undefined' or viewParam is 'incidents'

  locationView: ->
    Router.current().getParams()._view is 'locations'

  deleted: ->
    UserEvents.findOne(Template.instance().data.userEventId)?.deleted

  template: ->
    currentView = Router.current().getParams()._view
    templateName = switch currentView
      when 'estimated-epi-curves', undefined
        'eventResolvedIncidents'
      when 'affected-areas'
        'eventAffectedAreas'
      when 'incidents'
        'eventIncidentReports'
      when 'references'
        'eventReferences'
      when 'details'
        'eventDetails'
      else
        currentView

    name: templateName
    data:
      userEvent: UserEvents.findOne(Template.instance().data.userEventId)
      articles: EventArticles.find()
      incidents: EventIncidents.find()

  loaded: ->
    Template.instance().loaded.get()

  documentCount: ->
    EventArticles.find().count()


Template.curatedEvent.events
  # 'click .open-incident-form-in-details': (event, instance) ->
  #   Modal.show 'incidentModal',
  #     articles: EventArticles.find()
  #     userEventId: instance.data.userEventId
  #     add: true

  # 'click .open-source-form-in-details': (event, instance) ->
  #   Modal.show('sourceModal', userEventId: instance.data.userEventId)

  # 'click nav li a': (event, instance) ->
  #   instance.selectedView.set('resolvedIncidentsPlot')
  #   event.currentTarget.blur()
