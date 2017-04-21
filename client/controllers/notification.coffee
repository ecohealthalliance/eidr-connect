Template.notification.onCreated ->
  @active = new ReactiveVar(null)

Template.notification.onRendered ->
  instance = @
  delayTime = @data.delayTime or 2500
  # Ensure delay time is long enough to show the notification
  if delayTime <= 500
    delayTime += 500
  setTimeout ->
    instance.active.set('active')
  , 100
  setTimeout ->
    instance.$('.notification').addClass('dismissing')
  , (delayTime)
  setTimeout ->
    Blaze.remove(instance.view)
  , (delayTime + 1000)

Template.notification.helpers
  icon: ->
    switch @type
      when 'success' then 'check-circle'
      when 'failure', 'warning', 'error' then 'exclamation-triangle'
  active: ->
    Template.instance().active?.get()
