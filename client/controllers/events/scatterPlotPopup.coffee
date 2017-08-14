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
    $anchor = $(instance.firstNode)
    xOffset = instance.data.options.get().pageX or 0
    if $anchor.length
      result = xOffset - $anchor.offset().left
      if result <= ($anchor.outerWidth() / 2)
        result + 15

  right: ->
    instance = Template.instance()
    $anchor = $(instance.firstNode)
    xOffset = instance.data.options.get().pageX or 0
    if $anchor.length
      result = xOffset - $anchor.offset().left
      if result > ($anchor.outerWidth() / 2)
        $anchor.outerWidth() - result + 15

  top: ->
    instance = Template.instance()
    $anchor = $(instance.firstNode)
    yOffset = instance.data.options.get().pageY or 0
    if $anchor.length
      yOffset - $anchor.offset().top

  hidden: ->
    instance = Template.instance()
    options = instance.data.options.get()
    if options
      options.hidden
    else
      true

  incidents: ->
    Template.instance().data.options.get().incidents

Template.scatterPlotPopup.events
  'click .view-incident': (event, instance) ->
    incidentId = @_id
    if incidentId
      Modal.show 'incidentModal',
        incident: EventIncidents.findOne(incidentId)
