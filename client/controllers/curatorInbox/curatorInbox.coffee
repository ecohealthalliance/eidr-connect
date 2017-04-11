Articles = require '/imports/collections/articles'
Feeds = require '/imports/collections/feeds'
createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'
import { formatDateRange } from '/imports/ui/helpers'
import { keyboardSelect, debounceCheckTop } from '/imports/utils'
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

Template.curatorInbox.onDestroyed ->
  # cleanup the event handler
  @$('.curator-inbox-sources').off 'scroll'

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
  @selectedFeedId = new ReactiveVar()
  @subscribe 'feeds',
    onReady: =>
      @selectedFeedId.set(Feeds.findOne(title: 'ProMED-mail')._id)

Template.curatorInbox.onRendered ->
  # determine if our `back-to-top` button should be initially displayed
  $scrollableElement = @$('.curator-inbox-sources')
  $toTopButton = @$('.curator-inbox-sources--back-to-top')
  debounceCheckTop($scrollableElement, $toTopButton)
  # fadeIn/Out the `back-to-top` button based on if the div has scrollable content
  $scrollableElement.on 'scroll', ->
    debounceCheckTop($scrollableElement, $toTopButton)

  @autorun =>
    if @ready.get()
      Meteor.defer =>
        createNewCalendar(@latestSourceDate.get(), @dateRange.get())
        @$('[data-toggle="tooltip"]').tooltip
          container: 'body'
          placement: 'top'

  @autorun =>
    @filtering.set(true)
    range = @dateRange.get()
    endDate = range?.endDate
    startDate = range?.startDate
    query =
      publishDate:
        $gte: new Date(startDate)
        $lte: new Date(endDate)

    feedId = @selectedFeedId.get()
    switch feedId
      when 'userAdded' then query.addedByUserId = $exists: true
      when 'currentUser' then query.addedByUserId = Meteor.userId()
      else
        query.feedId = feedId

    @query.set(query)

    Meteor.call 'fetchPromedPosts', 100, range, (err) ->
      if err
        console.log(err)
        return toastr.error(err.reason)

    calendar = $('#date-picker').data('daterangepicker')
    if calendar
      updateCalendarSelection(calendar, range)

    @subscribe "articles", query, () =>
      unReviewedQuery = $and: [ {reviewed: false}, query ]
      firstSource = Articles.findOne unReviewedQuery,
        sort:
          publishDate: -1
      if firstSource
        @selectedSourceId.set(firstSource._id)
      @filtering.set(false)
      if not @latestSourceDate.get()
        @latestSourceDate.set Articles.findOne({},
            sort:
              publishDate: -1
            fields:
              publishDate: 1
          )?.publishDate
      @ready.set(true)

Template.curatorInbox.onDestroyed ->
  $('.inlineRangePicker').off('mouseleave')

Template.curatorInbox.helpers
  articles: ->
    Articles.find()

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

  feeds: ->
    feeds = Feeds.find().fetch()
    customFeeds = [
      {
        _id: 'userAdded'
        title: 'User Added'
      },
      {
        _id: 'currentUser'
        title: "Current User's"
      }
    ]
    feeds.concat(customFeeds)

  selectedFeed: ->
    @_id is Template.instance().selectedFeedId.get()

  noDocumentsMessage: ->
    instance = Template.instance()
    query = instance.query.get()
    selectedFeedId = instance.selectedFeedId.get()
    publishDate = query.publishDate
    dateRange = formatDateRange
      start: publishDate.$gte
      end: publishDate.$lte
    feedTitle = Feeds.findOne(selectedFeedId)?.title
    unless feedTitle
      if selectedFeedId is 'userAdded'
        feedTitle = 'User Added'
      else
        feedTitle = "Current user's"

    Spacebars.SafeString """
      No #{feedTitle} documents found
      <span class='secondary'>from #{dateRange}</span>
    """

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

  'change .curator-inbox--feed-selector': (event, instance) ->
    instance.selectedFeedId.set(event.currentTarget.value)
