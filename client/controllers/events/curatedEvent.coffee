import EventIncidents from '/imports/collections/eventIncidents'
import EventArticles from '/imports/collections/eventArticles'
import UserEvents from '/imports/collections/userEvents'

#Allow multiple modals or the suggested locations list won't show after the loading modal is hidden
Modal.allowMultiple = true

Template.curatedEvent.onCreated ->
  @loaded = new ReactiveVar(false)
  userEventId = @data.userEventId
  @selectedView = new ReactiveVar('resolvedIncidentsPlot')
  @filterQuery = new ReactiveVar({})
  @selectedIncidentTypes = new ReactiveVar([])

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
      selectedIncidentTypes: instance.selectedIncidentTypes
      articles: EventArticles.find()

  loaded: ->
    Template.instance().loaded.get()

  filterQuery: ->
    Template.instance().filterQuery

  selectedIncidentTypes: ->
    Template.instance().selectedIncidentTypes
