import Articles from '/imports/collections/articles.coffee'
import { keyboardSelect, pluralize } from '/imports/utils'

uniteReactiveTableFilters = (filters) ->
  reactiveFilters = []
  _.each filters, (filter) ->
    _filter = filter.get()
    if _filter
      reactiveFilters.push _.object filter.fields.map (field)->
        [field, _filter]
  reactiveFilters

Template.curatorInboxSection.onCreated ->
  @sourceCount = new ReactiveVar 0
  @curatorInboxFields = [
    {
      key: 'reviewed'
      description: 'Document has been curated'
      label: ''
      cellClass: (value) ->
        if value
          'curator-inbox-curated-row'
      sortDirection: -1
      fn: (value) ->
        ''
    },
    {
      key: 'title'
      description: 'The document\'s title.'
      label: 'Title'
      sortDirection: -1
      fn: (value, object)->
        object.title or object.url or (object.content?.slice(0,30) + "...")
    },
    {
      key: 'expand'
      label: ''
      cellClass: 'action open-right'
    },
  ]

  # Sort reactive table based on what type of feed is selected
  # by publishDate if feed like ProMed or by addedDate for user added and
  # current user lists
  dateSortField =
    key: 'publishDate'
    label: 'Publish Date'
    sortOrder: 1
    sortDirection: -1
    hidden: true
  if @data.sortKey is 'addedDate'
    dateSortField.key = 'addedDate'
    dateSortField.label = 'Added Date'
  @curatorInboxFields.push(dateSortField)

  sectionDate = Template.instance().data.date
  @filterId = 'inbox-date-filter-'+sectionDate.getTime()
  @filter = new ReactiveTable.Filter(@filterId, [@data.dateType])
  @filter.set
    $gte: sectionDate
    $lt: moment(sectionDate).add(1, 'day').toDate()

  @isOpen = new ReactiveVar(@data.index < 5)

Template.curatorInboxSection.onRendered ->
  @autorun =>
    data = @data
    sectionDate = data.date
    dateFilters = {}
    dateFilters[@data.dateType] =
      $gte: sectionDate
      $lt: moment(sectionDate).add(1, 'day').toDate()
    filters = uniteReactiveTableFilters [ data.textFilter, data.reviewFilter ]
    filters.push dateFilters
    query = $and: filters
    @sourceCount.set Articles.find(query).count()

Template.curatorInboxSection.helpers
  post: ->
    instance = Template.instance()
    query = {}
    query[instance.data.dateType] = instance.filter.get()
    Articles.findOne(query)

  posts: ->
    Articles.find().fetch()

  count: ->
    Template.instance().sourceCount.get()

  countText: ->
    pluralize('document', Template.instance().sourceCount.get())

  isOpen: ->
    Template.instance().isOpen.get()

  formattedDate: ->
    moment(Template.instance().data.date).format('MMMM DD, YYYY')

  settings: ->
    instance = Template.instance()
    fields = instance.curatorInboxFields
    id: "article-curation-table-#{instance.data.index}"
    showColumnToggles: false
    fields: fields
    showRowCount: false
    showFilter: false
    rowsPerPage: 200
    showNavigation: 'never'
    filters: [Template.instance().filterId, 'curator-inbox-article-filter', 'curator-inbox-review-filter']
    rowClass: (source) ->
      if source._id is instance.data.selectedSourceId.get()
        'selected'

Template.curatorInboxSection.events
  'click .curator-inbox-table tbody tr
    , keyup .curator-inbox-table tbody tr': (event, instance) ->
    return if not keyboardSelect(event) and event.type is 'keyup'
    instanceData = instance.data
    selectedSourceId = instanceData.selectedSourceId
    if selectedSourceId.get() != @_id
      selectedSourceId.set(@_id)
      instanceData.currentPaneInView.set('details')
    $(event.currentTarget).blur()

  'click .curator-inbox-section-head
    , keyup .curator-inbox-section-head': (event, instance) ->
    return if not keyboardSelect(event) and event.type is 'keyup'
    instance.isOpen.set(!instance.isOpen.curValue)
    $(event.currentTarget).blur()
