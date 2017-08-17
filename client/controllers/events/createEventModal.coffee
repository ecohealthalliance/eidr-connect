import { dismissModal } from '/imports/ui/modals'
import notify from '/imports/ui/notification'

handleCompletion = (error, objNameToAssociate, modal) ->
  if error
    notify('error', error.reason)
  else
    notify('success', "#{objNameToAssociate} successfully added to Event")
    dismissModal(modal)

Template.createEventModal.onRendered ->
  Meteor.defer ->
    @$('#createEvent').parsley()

Template.createEventModal.events
  'submit #createEvent': (event, instance) ->
    event.preventDefault()
    instanceData = instance.data
    target = event.target
    return unless $(target).parsley().isValid()
    summary = target.eventSummary?.value.trim()
    eventName = target.eventName
    source = instanceData?.source
    incidents = instanceData.incidents?.fetch()
    Meteor.call 'upsertUserEvent',
      eventName: eventName.value.trim()
      summary: summary
      displayOnPromed: event.target.promed.checked
    , (error, result) ->
      if error
        notify('error', error.reason)
      else
        modal = instance.$('#create-event-modal')
        if incidents?.length
          incidentIds = _.pluck(incidents, 'id')
          Meteor.call 'addIncidentsToEvent', incidentIds, result.insertedId, source, (error, res) ->
            handleCompletion(error, 'Incidents', modal)
        else if source
          Meteor.call 'addEventSource',
            url: source.url
            title: source.title
            publishDate: source.publishDate
            publishDateTZ: "EST",
            result.insertedId
          , (error) ->
            handleCompletion(error, 'Document', modal)
        else
          dismissModal(modal).then ->
            Router.go('curated-event', _id: result.insertedId)
