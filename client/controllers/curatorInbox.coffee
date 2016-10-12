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
  @textFilter = new ReactiveTable.Filter('curator-inbox-article-filter', ['url'])
  @reviewFilter = new ReactiveTable.Filter('curator-inbox-review-filter', ['reviewed'])
  
  @autorun =>
    Meteor.call 'fetchPromedPosts', 100, @dateRange.get(), (err) ->
      if err
        console.log(err)
        return toastr.error(err.reason)
      console.log "source cache updated"
    @subscribe "curatorSources", @dateRange.get(), () =>
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
    return days.reverse()

  calendarState: ->
    return Template.instance().calendarState.get()

  reviewedState: ->
    if Template.instance().reviewFilter.get()
      return false
    return true

  isReady: ->
    return Template.instance().ready.get()

  isLoading: ->
    return !Template.instance().ready.get()

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
  @curatorInboxFields = [
    {
      key: 'reviewed'
      description: 'Article has been curated'
      label: ''
      cellClass: (value) ->
        if value
          return 'curator-inbox-curated-row'
      sortDirection: -1
      fn: (value) ->
        return ''
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
        return moment(value).format('YYYY-MM-DD')
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

Template.curatorInboxSection.helpers
  posts: ->
    return CuratorSources
  isOpen: ->
    return Template.instance().isOpen.get()
  formattedDate: ->
    return moment(Template.instance().data.date).format('MMMM DD, YYYY')
  settings: ->
    fields = Template.instance().curatorInboxFields

    return {
      id: 'article-curation-table'
      showColumnToggles: false
      fields: fields
      showRowCount: false
      showFilter: false
      rowsPerPage: 200
      showNavigation: 'never'
      filters: [Template.instance().filterId, 'curator-inbox-article-filter', 'curator-inbox-review-filter']
    }

Template.curatorInboxSection.events
  "click .curator-inbox-table tbody tr": (event, template) ->
    $(".details-open").removeClass("details-open")
    $parentRow = $(event.target).closest("tr")
    $parentRow.addClass("details-open")
    $("#curator-article-details").html("")
    details = document.getElementById("curator-article-details")
    Blaze.renderWithData(Template.curatorSourceDetails, {_id: this._id}, details)
    if (window.scrollY > 0 and window.innerHeight < 700)
      $(document.body).animate({scrollTop: 0}, 400)
  "click .curator-inbox-section-head": (event, template) ->
    template.isOpen.set(!template.isOpen.curValue)


Template.curatorSourceDetails.onCreated ->
  @contentIsOpen = new ReactiveVar(false)

Template.curatorSourceDetails.helpers
  post: ->
    return CuratorSources.findOne({_id: @_id})
  content: ->
    content = Template.currentData().content
    if content
      if Template.instance().contentIsOpen.get()
        return content
      return lodash.truncate(content, {length: 250})
  largeContent: ->
    if Template.currentData().content and Template.currentData().content.length > 250
      return true
    return false
  contentIsOpen: ->
    return Template.instance().contentIsOpen.get()
  formattedScrapeDate: ->
    return moment(Template.instance().data.sourceDate).format('MMMM DD, YYYY')
  formattedPromedDate: ->
    return moment(Template.instance().data.promedDate).format('MMMM DD, YYYY')

Template.curatorSourceDetails.events
  "click #accept-article": (event, template) ->
    Meteor.call("curateSource", template.data._id, true)
    template.data.reviewed = true
  "click #content-show-more": (event, template) ->
    template.contentIsOpen.set(!template.contentIsOpen.curValue)
