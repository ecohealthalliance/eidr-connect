CuratorSources = require '/imports/collections/curatorSources.coffee'
createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'
{ keyboardSelect } = require '/imports/utils'
{ updateCalendarSelection } = require('/imports/ui/setRange')

createNewCalendar = (latestSourceDate, range) ->
  {startDate, endDate} = range
  createInlineDateRangePicker $("#date-picker"),
    maxDate: latestSourceDate
    dateLimit:
      days: 60
    useDefaultDate: true
  calendar = $('#date-picker').data('daterangepicker')
  updateCalendarSelection(calendar, range)

  $('.inlineRangePicker').on 'mouseleave', '.daterangepicker', ->
    if not calendar.endDate
      # Remove lingering classes that indicate pending range selection
      $(@).find('.in-range').each ->
        $(@).removeClass('in-range')
      # Update selection to indicate one date selected
      $(@).find('.start-date').addClass('end-date')

uniteReactiveTableFilters = (filters) ->
  reactiveFilters = []
  _.each filters, (filter) ->
    _filter = filter.get()
    if _filter
      reactiveFilters.push _.object filter.fields.map (field)->
        [field, _filter]
  reactiveFilters

###
# prevents checking the scrollTop more than every 50 ms to avoid flicker
# if the scrollTop is greater than zero, show the 'back-to-top' button
#
# @param [object] scrollableElement, the dom element from the scroll event
###
debounceCheckTop = _.debounce (scrollableElement) ->
    top = $(scrollableElement).scrollTop()
    if top > 0
      $('.back-to-top').fadeIn()
    else
      $('.back-to-top').fadeOut()
, 50

Template.curatorInbox.onDestroyed ->
  # cleanup the event handler
  $('.curator-inbox-sources').off 'scroll'

Template.curatorInbox.onCreated ->
  @calendarState = new ReactiveVar(false)
  @ready = new ReactiveVar(false)
  @selectedArticle = false
  today = new Date()
  @defaultDateRange =
    endDate: today
    startDate: moment(today).subtract(1, 'weeks').toDate()
  @dateRange = new ReactiveVar(@defaultDateRange)
  @textFilter =
    new ReactiveTable.Filter('curator-inbox-article-filter', ['title'])
  @reviewFilter =
    new ReactiveTable.Filter('curator-inbox-review-filter', ['reviewed'])
  @reviewFilter.set(null)
  @selectedSourceId = new ReactiveVar(null)
  @query = new ReactiveVar(null)
  @currentPaneInView = new ReactiveVar('')
  @latestSourceDate = new ReactiveVar(null)
  @filtering = new ReactiveVar(false)

Template.curatorInbox.onRendered ->
  # determine if our `back-to-top` button should be initially displayed
  $scrollableElement = $('.curator-inbox-sources')
  debounceCheckTop($scrollableElement)
  # fadeIn/Out the `back-to-top` button based on if the div has scrollable content
  $scrollableElement.on 'scroll', ->
    debounceCheckTop(@)

  @autorun =>
    if @ready.get()
      Meteor.defer =>
        createNewCalendar(@latestSourceDate.get(), @dateRange.get())
        @$('[data-toggle="tooltip"]').tooltip
          container: 'body'
          placement: 'left'

  @autorun =>
    @filtering.set(true)
    range = @dateRange.get()
    endDate = range?.endDate
    startDate = range?.startDate
    query =
      publishDate:
        $gte: new Date(startDate)
        $lte: new Date(endDate)
    @query.set query

    Meteor.call 'fetchPromedPosts', 100, range, (err) ->
      if err
        console.log(err)
        return toastr.error(err.reason)


    calendar = $('#date-picker').data('daterangepicker')
    if calendar
      updateCalendarSelection(calendar, range)

    @subscribe "curatorSources", query, () =>
      unReviewedQuery = $and: [ {reviewed: false}, query ]
      firstSource = CuratorSources.findOne unReviewedQuery,
        sort:
          publishDate: -1
      @selectedSourceId.set(firstSource._id)
      @filtering.set(false)
      if not @latestSourceDate.get()
        @latestSourceDate.set CuratorSources.findOne({},
            sort:
              publishDate: -1
            fields:
              publishDate: 1
          ).publishDate
        @ready.set(true)

Template.curatorInbox.onDestroyed ->
  $('.inlineRangePicker').off('mouseleave')

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
    instance = Template.instance()
    instance.ready.get() and not instance.filtering.get()

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

  detailsInView: ->
    Template.instance().currentPaneInView.get() is 'details'

  currentPaneInView: ->
    Template.instance().currentPaneInView

  userHasFilteredByDate: ->
    instance = Template.instance()
    not _.isEqual(instance.defaultDateRange, instance.dateRange.get())


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
      endDate = moment(startDate).set
        hour: 23
        minute: 59
        second: 59
        millisecond: 999

    if startDate and endDate
      range =
        startDate: startDate.toDate()
        endDate: endDate.toDate()
      instance.dateRange.set(range)

  'click #calendar-btn-reset': (event, instance) ->
    defaultDateRange = Template.instance().defaultDateRange
    instance.dateRange.set
      startDate: defaultDateRange.startDate
      endDate: defaultDateRange.endDate

  'click .back-to-top': (event, instance) ->
    event.preventDefault()
    # animate scrolling back to the top of the scrollable div
    $('.curator-inbox-sources').stop().animate
      scrollTop: 0
    , 500
    $('.back-to-top').fadeOut()

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
  'click .curator-inbox-table tbody tr
    , keyup .curator-inbox-table tbody tr': (event, instance) ->
    return if not keyboardSelect(event) and event.type is 'keyup'
    instanceData = instance.data
    instanceData.selectedSourceId.set(@_id)
    instanceData.currentPaneInView.set('details')
    $(event.currentTarget).blur()

  'click .curator-inbox-section-head
    , keyup .curator-inbox-section-head': (event, instance) ->
    return if not keyboardSelect(event) and event.type is 'keyup'
    instance.isOpen.set(!instance.isOpen.curValue)
    $(event.currentTarget).blur()
