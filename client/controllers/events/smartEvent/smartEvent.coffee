import SmartEvents from '/imports/collections/smartEvents'
import EventIncidents from '/imports/collections/eventIncidents'
#Allow multiple modals or the suggested locations list won't show after the
#loading modal is hidden
Modal.allowMultiple = true

Template.smartEvent.onCreated ->
  @editState = new ReactiveVar(false)
  @eventId = new ReactiveVar()
  @loaded = new ReactiveVar(false)
  @selectedView = new ReactiveVar('resolvedIncidentsPlot')
  @filterQuery = new ReactiveVar({})
  @selectedIncidentTypes = new ReactiveVar([])

  @hasNoIncidents = =>
    not EventIncidents.find().count()

Template.smartEvent.onRendered ->
  eventId = Router.current().getParams()._id
  @eventId.set(eventId)
  @subscribe 'smartEvent', eventId, =>
    @loaded.set(true)

Template.smartEvent.onRendered ->
  new Clipboard '.copy-link'

Template.smartEvent.helpers
  smartEvent: ->
    SmartEvents.findOne(Template.instance().eventId.get())

  isEditing: ->
    Template.instance().editState.get()

  deleted: ->
    SmartEvents.findOne(Template.instance().eventId.get())?.deleted

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
        'eventDetails'
      when 'references'
        'eventReferences'
      else
        currentView

    name: templateName
    data:
      eventType: "smartEvent"
      event: SmartEvents.findOne(instance.eventId.get())
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
    Template.instance().hasNoIncidents()

  noFilterMatches: ->
    instance = Template.instance()
    not EventIncidents.find(instance.filterQuery.get()).count()

Template.smartEvent.events
  'click .edit-link, click #cancel-edit': (event, instance) ->
    instance.editState.set(not instance.editState.get())
