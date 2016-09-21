Template.articles.onCreated ->
  @selectedSourceId = new ReactiveVar null

Template.articles.helpers
  getSettings: ->
    fields = [
      {
        key: "url"
        label: "Title"
        fn: (value, object, key) ->
          return value
      },
      {
        key: "addedDate"
        label: "Added"
        fn: (value, object, key) ->
          return moment(value).fromNow()
      },
      {
        key: "publishDate"
        label: "Publication Date"
        fn: (value, object, key) ->
          if value
            return moment(value).format('MMM D, YYYY')
          return ""
      }
    ]
    if Roles.userIsInRole(Meteor.userId(), ['admin'])
      fields.push({
        key: "delete"
        label: ""
        cellClass: "remove-row"
      })
      fields.push({
        key: "Edit"
        label: ""
        cellClass: "edit-row"
      })
    fields.push({
      key: "expand"
      label: ""
      cellClass: "open-row-right"
    })
    {
      id: 'event-sources-table'
      fields: fields
      showFilter: false
      showNavigationRowsPerPage: false
      showRowCount: false
      class: "table"
      filters: ["sourceFilter"]
    }
  selectedSource: ->
    selectedId = Template.instance().selectedSourceId.get()
    if selectedId
      Articles.findOne selectedId
  incidentsForSource: (sourceUrl) ->
    grid.Incidents.find({userEventId: Template.instance().data.userEvent._id, url: sourceUrl}).fetch()
  locationsForSource: (sourceUrl) ->
    locations = {}
    incidents = grid.Incidents.find({userEventId: Template.instance().data.userEvent._id, url: sourceUrl}).forEach( (incident) ->
      for location in incident.locations
        locations[location.id] = location.name
    )
    _.flatten locations

Template.articles.events
  "click .reactive-table tbody tr": (event, template) ->
    $target = $(event.target)
    $parentRow = $target.closest("tr")
    currentOpen = template.$("tr.tr-details")
    if $target.closest(".remove-row").length
      incidentCount = grid.Incidents.find({userEventId: this.userEventId, url: this.url}).count()
      if incidentCount
        plural = if incidentCount is 1 then "" else "s"
        message = "There " +
          (if incidentCount is 1 then "is an incident report" else "are #{incidentCount} incident reports") +
          " associated with this article. Please delete the incident report#{plural} before deleting the article."
        toastr.error(message)
      else if window.confirm("Are you sure you want to delete this event source?")
        currentOpen.remove()
        Meteor.call("removeEventSource", @_id)
    else if $target.closest(".edit-row").length
      modalData = @
      modalData.edit = true
      Modal.show("sourceModal", modalData)
    else if not $parentRow.hasClass("tr-details")
      closeRow = $parentRow.hasClass("details-open")
      ###
      if currentOpen
        template.$("tr").removeClass("details-open")
        currentOpen.remove()
      if not closeRow
        #TODO: Display event source details.
      ###
  "click #event-sources-table tbody tr": (event, templateInstance) ->
    event.preventDefault()
    templateInstance.selectedSourceId.set @_id
    $(event.currentTarget).parent().find('tr').removeClass("details-open")
    $(event.currentTarget).addClass("details-open")
  "click .open-source-form": (event, template) ->
    Modal.show("sourceModal", {userEventId: template.data.userEvent._id})


Template.articleSelect2.onRendered ->
  $input = @$("select")
  options = {}

  if @data.multiple
    options.multiple = true

  $input.select2(options)

  if @data.selected
    $input.val(@data.selected).trigger("change")
  $input.next(".select2-container").css("width", "100%")

Template.articleSelect2.onDestroyed ->
  templateInstance = Template.instance()
  templateInstance.$("#" + templateInstance.data.selectId).select2("destroy")
