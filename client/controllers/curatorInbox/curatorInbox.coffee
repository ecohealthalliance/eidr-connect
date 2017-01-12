CuratorSources = require '/imports/collections/curatorSources.coffee'
createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'

createNewCalendar = () ->
  createInlineDateRangePicker($("#date-picker"), {
    maxDate: new Date()
    dateLimit:
      days: 60
    useDefaultDate: true
  })
  calendar = $('#date-picker').data('daterangepicker')
  currentMonth = moment({ month: moment().month() })
  lastMonth = moment({ month: moment().subtract(1, 'months').month() })
  calendar.rightCalendar.month = currentMonth
  calendar.leftCalendar.month = lastMonth
  calendar.updateCalendars()

Template.curatorInbox.onCreated ->
  @calendarState = new ReactiveVar false
  @ready = new ReactiveVar false
  @selectedArticle = false
  @dateRange = new ReactiveVar
    startDate: moment().subtract(1, 'weeks').toDate()
    endDate: new Date()
  @textFilter = new ReactiveTable.Filter('curator-inbox-article-filter', ['title'])
  @reviewFilter = new ReactiveTable.Filter('curator-inbox-review-filter', ['reviewed'])
  @reviewFilter.set(null)
  @selectedSourceId = new ReactiveVar null
  @query = new ReactiveVar null

  @autorun =>
    range = @dateRange.get()
    endDate = range?.endDate || new Date()
    startDate = moment(endDate).subtract(2, 'weeks').toDate()
    if range?.startDate
      startDate = range.startDate
    query =
      publishDate:
        $gte: new Date(startDate)
        $lte: new Date(endDate)
    @query.set query

    Meteor.call 'fetchPromedPosts', 100, range, (err) ->
      if err
        console.log(err)
        return toastr.error(err.reason)

    @subscribe "curatorSources", query, () =>
      unReviewedQuery = $and: [ {reviewed: false}, query ]
      firstSource = CuratorSources.findOne unReviewedQuery,
        sort:
          publishDate: -1
      @selectedSourceId.set(firstSource._id)
      @ready.set(true)

Template.curatorInbox.onRendered ->
  Meteor.defer ->
    createNewCalendar()
    @$('[data-toggle="tooltip"]').tooltip
      container: 'body'
      placement: 'left'

Template.curatorInbox.helpers
  days: ->
    {startDate, endDate} = Template.instance().dateRange.get()
    days = _.range(moment(endDate).diff(startDate, 'days') + 1).map (dayOffset)->
      moment(startDate).add(dayOffset, 'days').set(
        hours:0
        minutes:0
        seconds:0
      ).toDate()
    days.reverse()

  calendarState: ->
    Template.instance().calendarState.get()

  reviewFilter: ->
    Template.instance().reviewFilter

  reviewFilterActive: ->
    Template.instance().reviewFilter.get()

  textFilter: ->
    Template.instance().textFilter

  isReady: ->
    Template.instance().ready.get()

  isLoading: ->
    !Template.instance().ready.get()

  selectedSourceId: ->
    Template.instance().selectedSourceId

  query: ->
    Template.instance().query

  searchSettings: ->
    id:"inboxFilter"
    textFilter: Template.instance().textFilter
    classes: 'option'
    placeholder: 'Search inbox'
    toggleable: true

Template.curatorInbox.events
  'click .curator-filter-reviewed-icon': (event, instance) ->
    reviewFilter = instance.reviewFilter
    if reviewFilter.get()
      reviewFilter.set null
    else
      reviewFilter.set $ne: true
    $(event.currentTarget).tooltip 'destroy'

  'click .curator-filter-calendar-icon': (event, instance) ->
    calendarState = instance.calendarState
    calendarState.set not calendarState.get()
    $(event.currentTarget).tooltip 'destroy'

  'click #calendar-btn-apply': (event, instance) ->
    range = null
    startDate = $('#date-picker').data('daterangepicker').startDate
    endDate = $('#date-picker').data('daterangepicker').endDate

    if startDate and !endDate
      endDate = moment(startDate).set({hour: 23, minute: 59, second: 59, millisecond: 999})

    if startDate and endDate
      instance.calendarState.set(false)
      instance.ready.set(false)
      range =
        startDate: startDate.toDate()
        endDate: endDate.toDate()
      instance.dateRange.set range

  'click #calendar-btn-reset': (event, instance) ->
    instance.calendarState.set(false)
    instance.ready.set(false)
    createNewCalendar()
    instance.dateRange.set
      startDate: moment().subtract(1, 'weeks').toDate()
      endDate: new Date()

  'click #calendar-btn-cancel': (event, instance) ->
    instance.calendarState.set(false)

Template.curatorInboxSection.onCreated ->
  @sourceCount = new ReactiveVar 0
  @curatorInboxFields = [
    {
      key: 'reviewed'
      description: 'Article has been curated'
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
      description: 'The source\'s title.'
      label: 'Title'
      sortDirection: -1
    },
    {
      key: 'publishDate'
      description: 'Date the article was published.'
      label: 'Published'
      sortOrder: 0
      sortDirection: -1
      sortFn: (value, ctx)->
        value
      fn: (value) ->
        if moment(value).diff(new Date(), 'days') > -7
          moment(value).fromNow()
        else
          moment(value).format('YYYY-MM-DD')
    },
    {
      key: 'addedDate'
      description: 'Date the article was added.'
      label: 'Added'
      sortDirection: -1
      hidden: true
      fn: (value) ->
        moment(value).format('YYYY-MM-DD')
    },
    {
      key: 'expand'
      label: ''
      cellClass: 'action open-right'
    }
  ]

  sectionDate = Template.instance().data.date
  @filterId = 'inbox-date-filter-'+sectionDate.getTime()
  @filter = new ReactiveTable.Filter(@filterId, ['publishDate'])
  @filter.set
    $gte: sectionDate
    $lt: moment(sectionDate).add(1, 'day').toDate()

  @isOpen = new ReactiveVar(@data.index < 5)

uniteReactiveTableFilters = (filters) ->
  reactiveFilters = []
  _.each filters, (filter) ->
    _filter = filter.get()
    if _filter
      reactiveFilters.push _.object filter.fields.map (field)->
        [field, _filter]
  reactiveFilters

Template.curatorInboxSection.onRendered ->
  @autorun =>
    data = @data
    sectionDate = data.date
    dateFilters =
      'publishDate':
        $gte: sectionDate
        $lt: moment(sectionDate).add(1, 'day').toDate()
    filters = uniteReactiveTableFilters [ data.textFilter, data.reviewFilter ]
    filters.push dateFilters
    query = $and: filters
    @sourceCount.set CuratorSources.find(query).count()

Template.curatorInboxSection.helpers
  post: ->
    CuratorSources.findOne publishDate: Template.instance().filter.get()

  posts: ->
    CuratorSources

  count: ->
    Template.instance().sourceCount.get()

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
      if source._id._str is instance.data.selectedSourceId.get()?._str
        'selected'

Template.curatorInboxSection.events
  'click .curator-inbox-table tbody tr': (event, instance) ->
    instance.data.selectedSourceId.set(@_id)

  'click .curator-inbox-section-head': (event, instance) ->
    instance.isOpen.set(!instance.isOpen.curValue)
