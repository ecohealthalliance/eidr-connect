{ manageTableSorting,
  tableFields,
  gotoEvent,
  scrollToTop } = require('/imports/reactiveTable')

Template.userEvents.onCreated ->
  tableName = 'user-events'
  @currentPage = new ReactiveVar(Session.get("#{tableName}-current-page") or 0)
  @rowsPerPage = new ReactiveVar(Session.get("#{tableName}-rows-per-page") or 10)
  @tableOptions =
    name: tableName
    fieldVisibility: {}
    sortOrder: {}
    sortDirection: {}
    fields: [
      {
        arrayName: '',
        description: 'The name of the EID.',
        displayName: 'Event Name',
        fieldName: 'eventName',
        defaultSortDirection: 1
      }
      {
        arrayName: '',
        description: 'The number of documents associated with the event.',
        displayName: 'Document Count',
        fieldName: 'articleCount',
        defaultSortDirection: 1
        displayFn: (value, object, key) ->
          new Spacebars.SafeString("<span data-heading='Document Count'>#{value}</span>")
      }
      {
        arrayName: '',
        description: 'Date last incident occured.',
        displayName: 'Last Incident Date',
        fieldName: 'lastIncidentDate',
        defaultSortDirection: -1,
        displayFn: (value, object, key) ->
          if value != null
            content = moment(value).format('MMM D, YYYY')
          else
            content = "No incidents"
          new Spacebars.SafeString("<span data-heading='Last Incident Date'>#{content}</span>")
      },
      {
        arrayName: '',
        description: 'Date the event was last modified.',
        displayName: 'Last Modified Date',
        fieldName: 'lastModifiedDate',
        defaultSortDirection: -1,
        displayFn: (value, object, key) ->
          if value != null
            content =  moment(value).format('MMM D, YYYY')
          else
            content =  "No date"
          new Spacebars.SafeString("<span data-heading='Last Modified Date'>#{content}</span>")
      }
    ]
  manageTableSorting(@)

Template.userEvents.helpers
  settings: ->
    instance = Template.instance()

    id: "#{instance.tableOptions.name}-table"
    fields: tableFields(instance)
    currentPage: instance.currentPage
    rowsPerPage: instance.rowsPerPage
    showRowCount: true
    showColumnToggles: false
    showFilter: false
    class: 'table featured'
    filters: ['eventFilter']
    showLoader: true
    noDataTmpl: Template.noResults

  searchSettings: ->
    id:"eventFilter"
    classes: 'event-search page-options--search'
    tableId: 'user-events-table'
    placeholder: 'Search Events'
    props: ['eventName']

Template.userEvents.events
  "click .reactive-table tbody tr": gotoEvent

  'click .next-page, click .previous-page': scrollToTop
