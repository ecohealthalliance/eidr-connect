CuratorSources = require '/imports/collections/curatorSources.coffee'
createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'

createNewCalendar = () ->
  createInlineDateRangePicker($("#date-picker"), {maxDate: new Date(), useDefaultDate: true})
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
  @reviewFilter.set({$ne: true})
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
      @selectedSourceId.set firstSource._id
      @ready.set(true)

Template.curatorInbox.onRendered ->
  $(document).ready =>
    createNewCalendar()

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

  isReady: ->
    Template.instance().ready.get()

  isLoading: ->
    !Template.instance().ready.get()

  selectedSourceId: ->
    Template.instance().selectedSourceId

  query: ->
    Template.instance().query

Template.curatorInbox.events
  "keyup #curator-inbox-article-filter, input #curator-inbox-article-filter": (event, template) ->
    template.textFilter.set($(event.target).val())

  "click .curator-filter-calendar-icon": (event, template) ->
    calendarState = template.calendarState
    calendarState.set not calendarState.get()

  "click .curator-filter-calendar-icon": (event, template) ->
    calendarState = template.calendarState
    calendarState.set not calendarState.get()

  "click .curator-filter-reviewed-icon": (event, template) ->
    if template.reviewFilter.get()
      template.reviewFilter.set(null)
    else
      template.reviewFilter.set({$ne: true})

  "click #calendar-btn-apply": (event, template) ->
    template.calendarState.set(false)
    template.ready.set(false)

    range = null
    startDate = $('#date-picker').data('daterangepicker').startDate
    endDate = $('#date-picker').data('daterangepicker').endDate

    if startDate and !endDate
      endDate = startDate

    if startDate and endDate
      range = {
        startDate: startDate.toDate()
        endDate: endDate.toDate()
      }
      template.dateRange.set range

  "click #calendar-btn-reset": (event, template) ->
    template.calendarState.set(false)
    template.ready.set(false)

    createNewCalendar()

    template.dateRange.set
      startDate: moment().subtract(1, 'weeks').toDate()
      endDate: new Date()

  "click #calendar-btn-cancel": (event, template) ->
    template.calendarState.set(false)

Template.curatorInboxSection.onCreated ->
  @selectedSourceId = new ReactiveVar null
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
      key: "expand"
      label: ""
      cellClass: "details-row"
    }
  ]

  sectionDate = Template.instance().data.date
  @filterId = 'inbox-date-filter-'+sectionDate.getTime()
  @filter = new ReactiveTable.Filter(@filterId, ['publishDate'])
  @filter.set(
    $gte: sectionDate
    $lt: moment(sectionDate).add(1, 'day').toDate()
  )

  @isOpen = new ReactiveVar(@data.index < 5)

Template.curatorInboxSection.onRendered ->
  @autorun =>
    sectionDate = @data.date
    reactiveFilters = @data.reviewFilter
    filters = @data.reviewFilter.get()
    filterArray = [
      'publishDate':
        $gte: sectionDate
        $lt: moment(sectionDate).add(1, 'day').toDate()
    ]
    # adjust counts based on whether we are showing accepted sources or not
    if filters
      filterArray.push _.object(reactiveFilters.fields.map((field)->
        [field, filters]
      ))
    filter = $and: filterArray
    @sourceCount.set CuratorSources.find(filter).count()

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

    id: 'article-curation-table'
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
  'click .curator-inbox-table tbody tr': (event, template) ->
    template.data.selectedSourceId.set @_id

  'click .curator-inbox-section-head': (event, template) ->
    template.isOpen.set(!template.isOpen.curValue)

Template.curatorSourceDetails.onCreated ->
  @contentIsOpen = new ReactiveVar(false)
  @notifying = new ReactiveVar false
  @source = new ReactiveVar null
  @reviewed = new ReactiveVar false

Template.curatorSourceDetails.onRendered ->
  @$('.toggle-source-content').tooltip()
  @autorun =>
    sourceId = Template.instance().data.selectedSourceId.get()
    source = CuratorSources.findOne _id: sourceId
    @reviewed.set source?.reviewed or false
    @source.set source

Template.curatorSourceDetails.helpers
  source: ->
    Template.instance().source.get()

  contentIsOpen: ->
    Template.instance().contentIsOpen.get()

  formattedScrapeDate: ->
    moment(Template.instance().data.sourceDate).format('MMMM DD, YYYY')

  formattedPromedDate: ->
    moment(Template.instance().data.promedDate).format('MMMM DD, YYYY')

  isReviewed: ->
    Template.instance().source.get().reviewed

  notifying: ->
    Template.instance().notifying.get()

  selectedSourceId: ->
    Template.instance().data.selectedSourceId

Template.curatorSourceDetails.events
  "click .toggle-reviewed": (event, template) ->
    reviewed = template.reviewed
    notifying = template.notifying
    reviewed.set not reviewed.get()
    Meteor.call('markSourceReviewed', template.source.get()._id, reviewed.get())
    if reviewed.get()
      notifying.set true
      Meteor.setTimeout ->
        unReviewedQuery = $and: [ {reviewed: false}, template.data.query.get()]
        nextSource = CuratorSources.findOne unReviewedQuery,
          sort:
            publishDate: -1
        template.data.selectedSourceId.set nextSource._id
        notifying.set false
      , 1200

  'click .toggle-source-content': (event, template) ->
    open = template.contentIsOpen
    open.set not open.get()
