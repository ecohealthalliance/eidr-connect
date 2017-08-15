Template.notification.onCreated ->
  @active = new ReactiveVar(null)

  @dismiss = (delayTime) =>
    setTimeout ->
      @$('.notification').addClass('dismissing')
    , (delayTime)
    setTimeout =>
      Blaze.remove(@view)
    , (delayTime + 1000)

Template.notification.onRendered ->
  delayTime = @data.delayTime or 3500
  # Ensure delay time is long enough to show the notification

  if delayTime <= 500
    delayTime += 500
  setTimeout =>
    @active.set('active')
  , 50
  if @data.type is 'success'
    @dismiss(delayTime)

Template.notification.helpers
  icon: ->
    switch @type
      when 'success' then 'check-circle'
      when 'failure', 'warning', 'error' then 'exclamation-triangle'
  active: ->
    Template.instance().active?.get()

Template.notification.events
  'click .notification,
   click .exit': (event, instance) ->
    instance.dismiss(0)
