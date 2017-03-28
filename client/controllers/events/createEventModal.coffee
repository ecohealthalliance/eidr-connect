CuratorSources = require '/imports/collections/curatorSources.coffee'
{ dismissModal } = require '/imports/ui/modals'

Template.createEventModal.onRendered ->
  Meteor.defer ->
    @$('#createEvent').validator
      # Do not disable inputs since we don't in other areas of the app
      disable: false

Template.createEventModal.events
  'submit #createEvent': (event, instance) ->
    return if event.isDefaultPrevented() # Form is invalid
    event.preventDefault()
    target = event.target
    summary = target.eventSummary?.value.trim()
    eventName = target.eventName
    source = instance.data?.source

    Meteor.call 'upsertUserEvent',
      eventName: eventName.value.trim()
      summary: summary
      displayOnPromed: event.target.promed.checked
    , (error, result) ->
      unless error
        modal = instance.$('#create-event-modal')
        if source
          Meteor.call 'addEventSource',
            url: "promedmail.org/post/#{source._sourceId}"
            userEventId: result.insertedId
            title: source.title
            publishDate: source.publishDate
            publishDateTZ: "EST"
            dismissModal(modal)
        else
          dismissModal(modal).then ->
            Router.go('user-event', _id: result.insertedId)
