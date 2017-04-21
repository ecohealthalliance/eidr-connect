module.exports =
  ###
  # notify - shows the notification template
  #
  # @param {string} type, the type of notification
  # @param {string} text, text to show in notification
  # @param {number} delayTime, duration of notification
  ###
  notify: (type, text, delayTime=2000) ->
    data =
      text: text
      type: type
      delayTime: delayTime
    Blaze.renderWithData Template.notification, data, $('body')[0]
