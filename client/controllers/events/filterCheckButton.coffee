Template.filterCheckButton.onCreated ->
  @state = new ReactiveVar(0)

Template.filterCheckButton.helpers
  state: ->
    switch Template.instance().state.get()
      when 0 then ''
      when 1 then 'positive'
      when 2 then 'negative'

  checked: ->
    state = Template.instance().state.get()
    if state == 1 or state == 2
      true

Template.filterCheckButton.events
  'click input': (event, instance) ->
    state = instance.state
    currentState = state.get()
    if currentState > 1
      state.set(0)
    else
      state.set( state.get() + 1 )
