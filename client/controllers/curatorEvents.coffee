Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
CuratorSources = require '/imports/collections/curatorSources.coffee'
Articles = require '/imports/collections/articles.coffee'

Template.curatorEvents.onCreated ->
  instance = @
  @autorun ->
    sourceId = instance.data.selectedSourceId.get()

    instance.subscribe("articles", {
      url:
        $regex: "post\/" + sourceId + "$"
    })
    instance.associatedEventIdsToArticles = new ReactiveVar([])

  @autorun =>
    @associatedEventIdsToArticles.set _.object(Articles.find(
      url:
        $regex: "post\/" + instance.data.selectedSourceId.get() + "$"
    ).map((article)->
      [article.userEventId, article]
    ))

Template.curatorEvents.onRendered ->
  @$('#curatorEventsFilter input').attr 'placeholder', 'Search events'

Template.curatorEvents.helpers
  userEvents: ->
    UserEvents.find(
      _id:
        $nin: _.keys(Template.instance().associatedEventIdsToArticles.get())
    )

  associatedUserEvents: ->
    UserEvents.find(
      _id:
        $in: _.keys(Template.instance().associatedEventIdsToArticles.get())
    )

  associatedEventIdsToArticles: ->
    Template.instance().associatedEventIdsToArticles

  title: ->
    Template.instance().data.title

  associated: () ->
    articleId = Template.instance().data._id
    CuratorSources.findOne({ _id: articleId, relatedEvents: this._id })

  settings: ->
    id: 'curator-events-table'
    class: 'table curator-events-table'
    fields: [
      {
        key: 'eventName'
        label: 'Event Name'
        sortDirection: 1
        tmpl: Template.curatorEventSearchRow
      }
      {
        key: 'creationDate'
        label: 'Creation Date'
        sortOrder: 0
        sortDirection: -1
        hidden: true
      }
    ]
    filters: ['curatorEventsFilter']
    noDataTmpl: Template.noCuratorEvents
    showNavigationRowsPerPage: false
    showColumnToggles: false
    showRowCount: false
    currentPage: 1
    rowsPerPage: 5

Template.curatorEvents.events
  "click .curator-events-table .curator-events-table-row": (event, template) ->
    $target = $(event.target)
    $parentRow = $target.closest("tr")
    $currentOpen = template.$("tr.tr-incidents")
    closeRow = $parentRow.hasClass("incidents-open")
    if $currentOpen
      template.$("tr").removeClass("incidents-open")
      $currentOpen.remove()
    if not closeRow
      $tr = $("<tr id='tr-incidents'>").addClass("tr-incidents")
      $parentRow.addClass("incidents-open").after($tr)
      Blaze.renderWithData(Template.curatorEventIncidents, this, $tr[0])
  "click .associate-event": (event, template) ->
    Meteor.call('addEventSource', {
      url: "promedmail.org/post/" + template.data.selectedSourceId.get(),
      userEventId: @_id
      publishDate: template.data.publishDate
      publishDateTZ: "EST"
    })
  "click .disassociate-event": (event, template) ->
    Meteor.call('removeEventSource', template.associatedEventIdsToArticles.get()[@_id])
  "click .suggest-incidents": (event, template) ->
    Modal.show("suggestedIncidentsModal", {
        userEventId: @_id
        article: template.associatedEventIdsToArticles.get()[@_id]
      })
