Incidents = require '/imports/collections/incidentReports.coffee'
UserEvents = require '/imports/collections/userEvents.coffee'
CuratorSources = require '/imports/collections/curatorSources.coffee'

Template.curatorEvents.onCreated ->
  @eventFields = [
    {
      key: "expand"
      label: ""
      cellClass: "open-row"
    },
    {
      key: 'eventName'
      label: 'Event Name'
      sortDirection: 1
      hidden: false
    },
    {
      key: 'creationDate'
      label: 'Creation Date'
      sortOrder: 0
      sortDirection: -1
      hidden: true
    }
  ]
  @addEventMenuIsOpen = new ReactiveVar false

Template.curatorEvents.helpers
  userEvents: ->
    UserEvents.find()

  associatedUserEvents: ->
    source = CuratorSources.findOne(this._id)
    if source?.relatedEvents and source.relatedEvents.length
      UserEvents.find({ _id: { $in: source.relatedEvents } })

  associated: () ->
    articleId = Template.instance().data._id
    CuratorSources.findOne({ _id: articleId, relatedEvents: this._id })

  settings: ->
    fields = []
    for field in Template.instance().eventFields
      fields.push {
        key: field.key
        label: field.label
        cellClass: field.cellClass
        sortOrder: field.sortOrder || 99
        sortDirection: field.sortDirection || 99
        sortable: false
        hidden: field.hidden
      }

    return {
      id: 'curator-events-table'
      showColumnToggles: false
      fields: fields
      showFilter: false
      showNavigationRowsPerPage: false
      showColumnToggles: false
      showRowCount: false
      currentPage: 1
      rowsPerPage: 5
      # showNavigation: 'never'
    }

  addEventMenuIsOpen: ->
    Template.instance().addEventMenuIsOpen.get()

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
  "click .open-add-event-form": (event, template) ->
    template.addEventMenuIsOpen.set !template.addEventMenuIsOpen.get()
  "click #associate-events tr, click #associated-events tr": (event, template) ->
    articleId = template.data._id
    Meteor.call 'associateEventWithSource', articleId, @_id

Template.curatorEventIncidents.onCreated ->
  Meteor.subscribe "eventIncidents", @data._id
  @filter = new ReactiveTable.Filter("incidentFilter_"+@data._id, ["userEventId"])
  @filter.set(@data._id)

  @fields = [
    {
      key: "count"
      label: "Incident"
      fn: (value, object, key) ->
        if object.cases
          return object.cases + " case" + (if object.cases isnt "1" then "s" else "")
        else if object.deaths
          return object.deaths + " death" + (if object.deaths isnt "1" then "s" else "")
        else
          return object.specify
    },
    {
      key: "locations"
      label: "Locations"
      fn: (value, object, key) ->
        if object.locations
          return $.map(object.locations, (element, index) ->
            return element.displayName
          ).toString()
        return ""
    },
    {
      key: "dateRange"
      label: "Date"
      fn: (value, object, key) ->
        dateFormat = "M/D/YYYY"
        if object.dateRange?.type is "day"
          if object.dateRange.cumulative
            return "Before " + moment(object.dateRange.end).format(dateFormat)
          else
            return moment(object.dateRange.start).format(dateFormat)
        else if object.dateRange?.type is "precise"
          return moment(object.dateRange.start).format(dateFormat) + " - " + moment(object.dateRange.end).format(dateFormat)
        return ""
    },
    {
      key: "delete"
      label: ""
      cellClass: "remove-row"
    },
    {
      key: "Edit"
      label: ""
      cellClass: "edit-row"
    }
  ]

Template.curatorEventIncidents.helpers
  incidents: ->
    return Incidents.find()

  settings: ->
    fields = []
    for field in Template.instance().fields
      fields.push {
        key: field.key
        label: field.label
        cellClass: field.cellClass
        fn: field.fn
        sortOrder: field.sortOrder || 99
        sortDirection: field.sortDirection || 99
        sortable: false
        hidden: field.hidden
      }

    return {
      id: 'curator-event-incidents-table'
      collection: 'curatorEventIncidents'
      fields: fields
      filters: ['incidentFilter_'+@_id]
      showFilter: false
      showNavigationRowsPerPage: false
      showColumnToggles: false
      showRowCount: false
      class: 'table table-hover curator-events-incidents-table'
      showNavigation: 'never'
    }

Template.curatorEventIncidents.events
  "click .reactive-table tbody tr": (event, template) ->
    $target = $(event.target)
    $parentRow = $target.closest("tr")
    currentOpen = template.$("tr.tr-details")
    if $target.closest(".remove-row").length
      if window.confirm("Are you sure you want to delete this incident report?")
        currentOpen.remove()
        Meteor.call("removeIncidentReport", @_id)
    else if $target.closest(".edit-row").length
      Modal.show("incidentModal", {
        articles: template.data.articles
        userEventId: this.userEventId
        edit: true
        incident: this
      })
