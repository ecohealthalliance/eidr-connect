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
    incidentCount:
      description: 'Number of incidents in the event'
      displayName: 'Incident Count'
      sortable: true
      sortOrder: 3
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
    lastIncidentDate:
      description: 'End date of the most recent incident.'
      displayName: 'Last Incident Date'
      defaultSortDirection: -1
      sortOrder: 1
      displayFn: (value, object, key) ->
        if value != null
          content =  moment(value).format('MMM D, YYYY')
        else
          content =  "No date"
        new Spacebars.SafeString("<span data-heading='Last Incident Date'>#{content}</span>")
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

    fields = switch eventType
      when 'smart'
        _.pick(fields, 'eventName', 'lastModifiedDate')
      when 'auto'
        _.pick(fields, 'eventName', 'incidentCount', 'lastIncidentDate')
      else
        _.pick(fields, 'eventName', 'incidents', 'lastModifiedDate')

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
    switch Template.instance().data.eventType.get()
      when 'curated'
        'userEvents'
      when 'smart'
        'smartEvents'
      when 'auto'
        'autoEvents'
      else
        'userEvents'

Template.eventsTable.events
  'click .reactive-table tbody tr': gotoEvent

  'click .next-page, click .previous-page': scrollToTop
