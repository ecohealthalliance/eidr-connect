{ manageTableSorting,
  tableFields,
  gotoEvent,
  scrollToTop } = require('/imports/reactiveTable')

Template.events.onCreated ->
  eventType = Router.current().getParams()._view
  @eventType = new ReactiveVar(eventType)
  @creatorFilter = new ReactiveTable.Filter('creatorFilter', ['createdByUserId'])
  @creatorFilter.set('')
  @showCurrentUserEvents = new ReactiveVar(false)
  @currentPage = new ReactiveVar(Session.get("#{@eventType.get()}-current-page") or 0)
  @rowsPerPage = new ReactiveVar(Session.get("#{@eventType.get()}-rows-per-page") or 10)
  @tableOptions =
    name: @eventType.get()
    fieldVisibility: {}
    sortOrder: {}
    sortDirection: {}
    fields: [
      {
        arrayName: ''
        description: 'The name of the EID.'
        displayName: 'Event Name'
        fieldName: 'eventName',
        defaultSortDirection: 1
      }
      {
        arrayName: '',
        displayName: 'Created By'
        description: 'User who created the event.'
        fieldName: 'createdByUserName'
        defaultSortDirection: 1
      }
      {
        arrayName: ''
        description: 'Date the event was last modified.'
        displayName: 'Last Modified Date'
        fieldName: 'lastModifiedDate'
        defaultSortDirection: -1
        displayFn: (value, object, key) ->
          if value != null
            content =  moment(value).format('MMM D, YYYY')
          else
            content =  "No date"
          new Spacebars.SafeString("<span data-heading='Last Modified Date'>#{content}</span>")
      }
    ]
  if eventType is 'curated'
    @tableOptions.fields.splice 1, 0,
      arrayName: '',
      description: 'The number of documents associated with the event.',
      displayName: 'Document Count',
      fieldName: 'articleCount',
      defaultSortDirection: 1
      displayFn: (value, object, key) ->
        new Spacebars.SafeString("<span data-heading='Document Count'>#{value}</span>")

  manageTableSorting(@)

Template.events.onRendered ->
  @autorun =>
    @eventType.set(Router.current().getParams()._view)

Template.events.helpers
  settings: ->
    instance = Template.instance()

    id: "#{instance.eventType.get()}-events-table"
    fields: tableFields(instance)
    currentPage: instance.currentPage
    rowsPerPage: instance.rowsPerPage
    showRowCount: true
    showColumnToggles: false
    showFilter: false
    class: 'table featured'
    filters: ['smartEventFilter', 'creatorFilter']
    showLoader: true
    noDataTmpl: Template.noResults

  searchSettings: ->
    eventType = Template.instance().eventType.get()
    id: 'smartEventFilter'
    classes: 'event-search page-options--search'
    tableId: "#{eventType}-events-table"
    placeholder: "Search #{eventType} Events"
    props: ['eventName']

  showCurrentUserEventsChecked: ->
    Template.instance().showCurrentUserEvents.get()

  activeTab: (tab) ->
    tab is Template.instance().eventType.get()

  collection: ->
    if Template.instance().eventType.get() is 'curated'
      'userEvents'
    else
      'smartEvents'

  eventType: ->
    Template.instance().eventType.get()

  showUserOptions: ->
    Template.instance().eventType.get() is 'smart' and Meteor.user()

Template.events.events
  'click .reactive-table tbody tr': gotoEvent

  'click .next-page, click .previous-page': scrollToTop

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
    event.currentTarget.blur()

  'click .create-event': (event, instance) ->
    if instance.eventType.get() is 'curated'
      modal = 'createEventModal'
    else
      modal = 'editSmartEventDetailsModal'
    Modal.show(modal, action: 'add')
