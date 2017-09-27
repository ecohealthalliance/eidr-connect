Template.filterCheckButton.onCreated ->
  @state = new ReactiveVar(0)

  @textBasedOnState = (text) ->
    switch @state.get()
      when 0 then ''
      when 1 then text[0]
      when 2 then text[1]

Template.filterCheckButton.onRendered ->
  @$('[data-toggle=tooltip]').tooltip
    placement: 'bottom'

Template.filterCheckButton.helpers
  state: ->
    Template.instance().textBasedOnState(['positive', 'negative'])

  checked: ->
    state = Template.instance().state.get()
    if state == 1 or state == 2
      true

  tooltipTitle: ->
    instance = Template.instance()
    return unless instance.data.showtooltip
    instance.textBasedOnState(
      [
        'Click again to exclude from filtration'
        'Click again to set to default'
      ]
    )

Template.filterCheckButton.events
  'click input': (event, instance) ->
    state = instance.state
    currentState = state.get()
    if currentState > 1
      state.set(0)
      instance.$('[data-toggle=tooltip]').tooltip('destroy')
    else
      state.set( state.get() + 1 )
    # Force tooltip of input's label to show
    Meteor.defer ->
      inputLabel = $(event.currentTarget).next()
      toolTipAction = 'show'
      if currentState == 2
        toolTipAction = 'hide'
      inputLabel.tooltip(toolTipAction)
