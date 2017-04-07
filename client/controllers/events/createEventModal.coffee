{ dismissModal } = require '/imports/ui/modals'
{ notify } = require '/imports/ui/notification'

handleCompletion = (error, objNameToAssociate, modal) ->
  if error
    notify('error', error.reason)
  else
    notify('success', "#{objNameToAssociate} successfully added to Event")
    dismissModal(modal)

Template.createEventModal.onRendered ->
  Meteor.defer ->
    @$('#createEvent').validator
      # Do not disable inputs since we don't in other areas of the app
      disable: false

Template.createEventModal.events
  'submit #createEvent': (event, instance) ->
    instanceData = instance.data
    return if event.isDefaultPrevented() # Form is invalid
    event.preventDefault()
    target = event.target
    summary = target.eventSummary?.value.trim()
    eventName = target.eventName
    source = instanceData?.source
    incidents = instanceData.incidents?.fetch()

    Meteor.call 'upsertUserEvent',
      eventName: eventName.value.trim()
      summary: summary
      displayOnPromed: event.target.promed.checked
    , (error, result) ->
      unless error
        modal = instance.$('#create-event-modal')
        if incidents?.length
          incidentIds = _.pluck(incidents, 'id')
          Meteor.call 'addIncidentsToEvent', incidentIds, result.insertedId, source, (error, res) ->
            handleCompletion(error, 'Incidents', modal)
        else if source
          Meteor.call 'addEventSource',
            url: source.url
            userEventId: result.insertedId
            title: source.title
            publishDate: source.publishDate
            publishDateTZ: "EST"
          , (error) ->
            handleCompletion(error, 'Document', modal)
        else
          dismissModal(modal).then ->
            Router.go('curated-event', _id: result.insertedId)
