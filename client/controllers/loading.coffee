Template.loading.helpers
  showSmall: ->
    if Template.instance().data?.small
      "-small"

  message: ->
    Template.instance().data?.message or 'Loading'
