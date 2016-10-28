Incidents = require '/imports/collections/incidentReports.coffee'
ScatterPlot = require '/imports/charts/ScatterPlot.coffee'
Axes = require '/imports/charts/Axes.coffee'
RectMarker = require '/imports/charts/RectMarker.coffee'
tooltipTmpl = """
  <div class='row'>
    <div class='col-xs-12'>
      <span style='font-weight: bold;'>
        <%= obj.y %> <%= type %> (<%= obj.meta.location %>)</span>
      </span>
    </div>
  </div>
  <div class='row'>
    <div class='col-xs-12'>
      <span style='text-align: left; padding-left: 5px;'>
        from <%= obj.moment(obj.x).format('MMM Do YYYY') %>
        to <%= obj.moment(obj.w).format('MMM Do YYYY') %>
      </span>
    </div>
  </div>
"""

import { formatUrl } from '/imports/utils.coffee'


Template.incidentReports.onDestroyed ->
  if @plot
    @plot.destroy()
    @plot = null

Template.incidentReports.onCreated ->
  # iron router returns an array and not a cursor for data.incidents,
  # therefore we will setup a reactive cursor to use with the plot as an
  # instance variable.
  @incidents = Incidents.find({userEventId: @data.userEvent._id}, {sort: {date: -1}})

Template.incidentReports.onRendered ->
  @filters =
    notCumulative: (d) ->
      if typeof d.meta.cumulative == 'undefined' || d.meta.cumulative == false
        return d
    cumulative: (d) ->
      if d.meta.cumulative
        return d

  @plot = new ScatterPlot({
    containerID: 'scatterPlot',
    svgContainerClass: 'scatterPlot-container',
    height: $('#event-incidents-table').parent().height(),
    axes: {
      # show grid lines
      grid: true,
      x: {
        title: 'Time',
        type: 'datetime',
      },
      y: {
        title: 'Count',
        type: 'numeric',
      }
    },
    tooltip: {
      opacity: .8
      # function to render the tooltip
      template: (marker) ->
        marker.moment = moment # template reference for momentjs
        marker.type = marker.meta.type
        if marker.y != 1
          marker.type = "#{marker.type}s"
        # underscore compiled template
        tmpl = _.template(tooltipTmpl)
        # render the template from
        tmpl(marker)
    },
    zoom: true,
    # initially active filters
    filters: {
      notCumulative: @filters.notCumulative
    }
  })
  # deboune how many consecutive calls to update the plot during reactive changes
  @updatePlot = _.debounce(_.bind(@plot.update, @plot), 300)

  @autorun =>
    # anytime the incidents cursur changes, refetch the data and format
    incidents = @incidents.fetch().map((incident) =>
      return RectMarker.createFromIncident(incident)
    ).filter((incident) =>
      if incident
        return incident
    )
    # we have an existing plot, update plot with new data array
    if @plot instanceof ScatterPlot
      @updatePlot(incidents)
      return

Template.incidentReports.helpers
  formatUrl: (url) ->
    formatUrl(url)
  getSettings: ->
    fields = [
      {
        key: "count"
        label: "Incident"
        fn: (value, object, key) ->
          if object.cases
            return pluralize("case", object.cases)
          else if object.deaths
            return pluralize("death", object.deaths)
          else
            return object.specify
        sortFn: (value, object) ->
          0 + (object.deaths or 0) + (object.cases or 0)
      },
      {
        key: "locations"
        label: "Locations"
        fn: (value, object, key) ->
          if object.locations
            return $.map(object.locations, (element, index) ->
              return element.name
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
            return moment(object.dateRange.start).format(dateFormat) + " - "
            + moment(object.dateRange.end).format(dateFormat)
          return ""
        sortFn: (value, object) ->
          +new Date(object.dateRange.end)
      },
      {
        key: "travelRelated"
        label: "Travel Related"
        fn: (value, object, key) ->
          if value
            return "Yes"
          return ""
      },
      {
        key: "species"
        label: "Species"
      }
    ]

    if Meteor.user()
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
      cellClass: "open-row"
    })

    return {
      id: 'event-incidents-table'
      fields: fields
      showFilter: false
      showNavigationRowsPerPage: false
      showRowCount: false
      class: "table"
    }

Template.incidentReports.events
  "click #scatterPlot-toggleCumulative": (event, template) ->
    $target = $(event.currentTarget)
    $icon = $target.find('i.fa')
    if $target.hasClass('active')
      $target.removeClass('active')
      $icon.removeClass('fa-check-circle').addClass('fa-circle-o')
      template.plot.removeFilter('cumulative')
      template.plot.addFilter('notCumulative', template.filters.notCumulative)
      template.updatePlot()
    else
      $target.addClass('active')
      $icon.removeClass('fa-circle-o').addClass('fa-check-circle')
      template.plot.removeFilter('notCumulative')
      template.plot.addFilter('cumulative', template.filters.cumulative)
      template.updatePlot()
  "click #scatterPlot-resetZoom": (event, template) ->
    template.plot.resetZoom()
  "click #event-incidents-table th": (event, template) ->
    template.$("tr").removeClass("details-open")
    template.$("tr.tr-details").remove()
  "click .reactive-table tbody tr": (event, template) ->
    $target = $(event.target)
    $parentRow = $target.closest("tr")
    currentOpen = template.$("tr.tr-details")
    if $target.closest(".remove-row").length
      if window.confirm("Are you sure you want to delete this incident report?")
        currentOpen.remove()
        Meteor.call("removeIncidentReport", @_id)
    else if $target.closest(".edit-row").length
      Modal.show("incidentModal", {articles: template.data.articles, userEventId: template.data.userEvent._id, edit: true, incident: this})
    else if not $parentRow.hasClass("tr-details")
      closeRow = $parentRow.hasClass("details-open")
      if currentOpen
        template.$("tr").removeClass("details-open")
        currentOpen.remove()
      if not closeRow
        $tr = $("<tr>").addClass("tr-details").html(Blaze.toHTMLWithData(Template.incidentReport, this))
        $parentRow.addClass("details-open").after($tr)
