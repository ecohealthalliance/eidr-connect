import Articles from '/imports/collections/articles'
import UserEvents from '/imports/collections/userEvents'
import { debounceCheckTop, keyboardSelect } from '/imports/utils'

Template.eventInbox.onCreated ->
  @ready = new ReactiveVar(false)
  @filtering = new ReactiveVar(false)
  @selectedSourceId = new ReactiveVar(null)

Template.eventInbox.onDestroyed ->
  # cleanup the event handler
  @$('.curator-inbox-sources').off 'scroll'

Template.eventInbox.onRendered ->
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
        @$('[data-toggle="tooltip"]').tooltip
          container: 'body'
          placement: 'bottom'

  @selectFirstUnreviewed = =>
    unReviewedQuery =
      reviewed: $in: [false, null]
    firstSource = Articles.findOne(unReviewedQuery, sort: addedDate: -1)
    if firstSource
      @selectedSourceId.set(firstSource._id)
    @ready.set(true)

  # TODO Get id from router
  @subscribe "userEvent", "YqpQ8B6QkTysGeR4Q", @selectFirstUnreviewed

Template.eventInbox.onDestroyed ->
  $('.inlineRangePicker').off('mouseleave')

Template.eventInbox.helpers
  isReady: ->
    instance = Template.instance()
    instance.ready.get() and not instance.filtering.get()

  selectedSourceId: ->
    Template.instance().selectedSourceId

  event: ->
    UserEvents.findOne("YqpQ8B6QkTysGeR4Q")

  documents: ->
    Articles.find().fetch()

  tableSettings: ->
    instance = Template.instance()

    id: "article-curation-table"
    showColumnToggles: false
    fields: [
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
      {
        key: 'addedDate'
        sortOrder: 1
        sortDirection: -1
        hidden: true
      }
    ]
    showRowCount: false
    showFilter: false
    rowsPerPage: 200
    showNavigation: 'never'
    filters: ['curator-inbox-article-filter', 'curator-inbox-review-filter']
    rowClass: (source) ->
      if source._id is instance.selectedSourceId.get()
        'selected'

  eventId: ->
    Router.current().params._id

Template.eventInbox.events
  'click .back-to-top': (event, instance) ->
    event.preventDefault()
    # animate scrolling back to the top of the scrollable div
    $('.curator-inbox-sources').stop().animate
      scrollTop: 0
    , 500

  'click .add-document': (event, instance) ->
    Modal.show 'sourceModal',
      userEventId: "YqpQ8B6QkTysGeR4Q"
      suggest: false
      selectedSourceId: instance.selectedSourceId

  'sourceReviewed': (event, instance) ->
    instance.selectFirstUnreviewed()

  'click .curator-inbox-table tbody tr
    , keyup .curator-inbox-table tbody tr': (event, instance) ->
    return if not keyboardSelect(event) and event.type is 'keyup'
    selectedSourceId = instance.selectedSourceId
    if selectedSourceId.get() != @_id
      selectedSourceId.set(@_id)
    $(event.currentTarget).blur()
