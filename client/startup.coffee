Meteor.startup ->
  Session.set('WIDE_UI_WIDTH', 1500)

  $(document)
    .on 'show.bs.modal', ->
      $(@).on 'keyup', (event) ->
        if event.keyCode is 27
          $('.modal').each (modal) -> $(@).modal 'hide'
    .on 'hide.bs.modal', ->
      $(@).off 'keyup'
    .on 'shown.bs.modal', ->
      $('.modal-content').find('.form-control').first().focus()

  $('html').attr('lang', 'en')
