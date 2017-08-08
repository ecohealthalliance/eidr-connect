import {
  manageTableSorting,
  tableFields,
  gotoEvent,
  scrollToTop } from '/imports/reactiveTable'

Template.eventsTable.onCreated ->
  eventType = @data.eventType.get()
  @currentPage = new ReactiveVar(Session.get("#{eventType}-current-page") or 0)
  @rowsPerPage = new ReactiveVar(Session.get("#{eventType}-rows-per-page") or 10)
  fields =
    eventName:
      description: 'The name of the EID.'
      displayName: 'Event Name'
      defaultSortDirection: 1
      sortOrder: 2
    incidents:
      description: 'Number of incidents associated with event'
      displayName: 'Incident Count'
      sortable: false
      sortOrder: 3
      displayFn: (value, object) ->
        value?.length or 0
    lastModifiedDate:
      description: 'Date the event was last modified.'
      displayName: 'Last Modified Date'
      defaultSortDirection: -1
      sortOrder: 1
      displayFn: (value, object, key) ->
        if value != null
          content =  moment(value).format('MMM D, YYYY')
        else
          content =  "No date"
        new Spacebars.SafeString("<span data-heading='Last Modified Date'>#{content}</span>")
  @tableOptions =
    fieldVisibility: {}
    sortOrder: {}
    sortDirection: {}
    fields: fields
    name: eventType
  manageTableSorting(@)

Template.eventsTable.helpers
  settings: ->
    instance = Template.instance()
    eventType = instance.data.eventType.get()
    fields = instance.tableOptions.fields

    if eventType is 'smart'
      fields = _.omit(fields, 'incidents')

    id: "#{eventType}-events-table"
    fields: tableFields(fields, instance.tableOptions)
    currentPage: instance.currentPage
    rowsPerPage: instance.rowsPerPage
    showRowCount: true
    showColumnToggles: false
    showFilter: false
    class: 'table featured'
    filters: ['eventFilter', 'creatorFilter']
    showLoader: true
    noDataTmpl: Template.noResults

  collection: ->
    if Template.instance().data.eventType.get() is 'curated'
      'userEvents'
    else
      'smartEvents'

Template.eventsTable.events
  'click .reactive-table tbody tr': gotoEvent

  'click .next-page, click .previous-page': scrollToTop
