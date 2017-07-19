Template.eventNav.helpers
  id: ->
    instanceData = Template.instance().data
    instanceData.userEventId or instanceData.smartEventId

  route: ->
    if Template.instance().data.userEventId
      'curated-event'
    else
      'smart-event'
