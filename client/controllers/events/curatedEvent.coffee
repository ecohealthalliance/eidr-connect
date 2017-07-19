EventIncidents = require '/imports/collections/eventIncidents'
EventArticles = require '/imports/collections/eventArticles'
UserEvents = require '/imports/collections/userEvents'

#Allow multiple modals or the suggested locations list won't show after the loading modal is hidden
Modal.allowMultiple = true

Template.curatedEvent.onCreated ->
  @loaded = new ReactiveVar(false)
  userEventId = @data.userEventId
  @selectedView = new ReactiveVar('resolvedIncidentsPlot')
  @filterQuery = new ReactiveVar({})

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
    EventIncidents.find(Template.instance().filterQuery.get())

  incidentCount: ->
    EventIncidents.find(Template.instance().filterQuery.get()).count()

  incidentView: ->
    viewParam = Router.current().getParams()._view
    typeof viewParam is 'undefined' or viewParam is 'incidents'

  locationView: ->
    Router.current().getParams()._view is 'locations'

  deleted: ->
    UserEvents.findOne(Template.instance().data.userEventId)?.deleted

  template: ->
    instance = Template.instance()
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
      userEvent: UserEvents.findOne(instance.data.userEventId)
      filterQuery: instance.filterQuery

  loaded: ->
    Template.instance().loaded.get()

  documentCount: ->
    EventArticles.find().count()

  filterQuery: ->
    Template.instance().filterQuery
