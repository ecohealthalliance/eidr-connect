###
# shows the notification template
#
# @param {string} type, the type of notification
# @param {string} text, text to show in notification
# @param {number} delayTime, duration of notification
###
module.exports = (type, text, delayTime=5000) ->
  data =
    text: text
    type: type
    delayTime: delayTime
  Blaze.renderWithData Template.notification, data, $('body')[0]
