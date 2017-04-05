Template.events.onCreated ->
  @eventType = new ReactiveVar(null)
  @creatorFilter = new ReactiveTable.Filter('creatorFilter', ['createdByUserId'])
  @creatorFilter.set('')
  @showCurrentUserEvents = new ReactiveVar(false)

  @autorun =>
    @eventType.set(Router.current().getParams()._view)

Template.events.helpers
  searchSettings: ->
    eventType = Template.instance().eventType.get()
    id: 'eventFilter'
    classes: 'event-search page-options--search'
    tableId: "#{eventType}-events-table"
    placeholder: "Search #{eventType} Events"
    props: ['eventName']

  showCurrentUserEventsChecked: ->
    Template.instance().showCurrentUserEvents.get()

  activeTab: (tab) ->
    tab is Template.instance().eventType.get()

  eventTypeText: ->
    Template.instance().eventType.get()

  eventType: ->
    Template.instance().eventType

  showUserOptions: ->
    Template.instance().eventType.get() is 'smart' and Meteor.user()

  filters: ->
    Template.instance()

Template.events.events
  'click .show-current-user-events': (event, instance) ->
    filterSelector = ''
    creatorFilter = instance.creatorFilter
    showCurrentUserEvents = instance.showCurrentUserEvents
    if not creatorFilter.get()
      filterSelector = $eq: Meteor.userId()
    showCurrentUserEvents.set(not showCurrentUserEvents.get())
    creatorFilter.set(filterSelector)
    $(event.currentTarget).blur()

  'click .tab a': (event, instance) ->
    ReactiveTable.clearFilters(['smartEventFilter'])
    event.currentTarget.blur()

  'click .create-event': (event, instance) ->
    if instance.eventType.get() is 'curated'
      modal = 'createEventModal'
    else
      modal = 'editSmartEventDetailsModal'
    Modal.show(modal, action: 'add')
