import EventIncidents from '/imports/collections/eventIncidents'

Template.scatterPlotPopup.onCreated ->
  # Hide popup when the user clicks on something else
  @clickHandler = (event) =>
    if not event.isDefaultPrevented()
      options = _.extend(@data.options.get(), hidden: true)
      @data.options.set(options)
  $(document).on('click', @clickHandler)

Template.scatterPlotPopup.onDestroyed ->
  $(document).off('click', @clickHandler)

Template.scatterPlotPopup.helpers
  left: ->
    instance = Template.instance()
    anchor = $(instance.firstNode).offset()
    if not anchor
      return 0
    (instance.data.options.get().pageX or 0) - anchor.left
  top: ->
    instance = Template.instance()
    anchor = $(instance.firstNode).offset()
    if not anchor
      return 0
    (instance.data.options.get().pageY or 0)  - anchor.top
  hidden: ->
    instance = Template.instance()
    console.log instance.data.options.get()
    instance.data.options.get()?.hidden
  incidents: ->
    Template.instance().data.options.get().incidents

Template.scatterPlotPopup.events
  'click .view-incident': (event, instance) ->
    incidentId = @_id
    if incidentId
      Modal.show 'incidentModal',
        incident: EventIncidents.findOne(incidentId)

