import AutoEvents from '/imports/collections/autoEvents'
import EventIncidents from '/imports/collections/eventIncidents'

Template.autoEvent.onCreated ->
  @eventId = new ReactiveVar()
  @loaded = new ReactiveVar(false)
  @selectedView = new ReactiveVar('resolvedIncidentsPlot')
  @filterQuery = new ReactiveVar({})
  @selectedIncidentTypes = new ReactiveVar([])

  eventId = Router.current().getParams()._id
  @eventId.set(eventId)
  @subscribe 'autoEvent', eventId, =>
    @loaded.set(true)

Template.autoEvent.helpers
  event: ->
    AutoEvents.findOne(Template.instance().eventId.get())

  loaded: ->
    Template.instance().loaded.get()

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
      when 'details'
        'autoEventDetails'
      else
        currentView

    name: templateName
    data:
      event: AutoEvents.findOne(instance.eventId.get())
      filterQuery: instance.filterQuery
      selectedIncidentTypes: instance.selectedIncidentTypes

  filterQuery: ->
    Template.instance().filterQuery

  selectedIncidentTypes: ->
    Template.instance().selectedIncidentTypes

  filterableView: ->
    instance = Template.instance()
    instance.loaded.get() and Router.current().getParams()._view not in ['references', 'details']

  noIncidents: ->
    not EventIncidents.find().count()

  noFilterMatches: ->
    instance = Template.instance()
    not EventIncidents.find(instance.filterQuery.get()).count()
