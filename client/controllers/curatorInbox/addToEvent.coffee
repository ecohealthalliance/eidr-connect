UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
{ notify } = require '/imports/ui/notification'

Template.addToEvent.onCreated ->
  @subscribe('userEvents')
  @subscribe('article', @data.source._sourceId)
  @selectedEventId = new ReactiveVar(null)

Template.addToEvent.onRendered ->
  instanceData = @data
  # If showing accepted IRs instantiate select2 input and register event to
  # show 'Create Event' modal
  Meteor.defer =>
    events = UserEvents.find {},
      fields: eventName: 1
      sort: eventName: 1
    $select2 = @$('.select2')
    select2Data = events.map (event) ->
      id: event._id
      text: event.eventName
    $select2.select2
      data: select2Data
      placeholder: 'Search for an Event...'
      minimumInputLength: 0

    $(document).on 'click', '.add-new-event', (event) ->
      event.stopPropagation()
      eventName = $('.select2-search__field').val()
      $select2.select2('close')
      Modal.show 'createEventModal',
        associationMessage: " & Associate #{instanceData.objNameToAssociate}"
        eventName: eventName
        incidents: instanceData.selectedIncidents
        source: instanceData.source

Template.addToEvent.helpers
  selectingEvent: ->
    Template.instance().selectingEvent.get()

  allowAddingEvent: ->
    Template.instance().selectedEventId.get()

  whatToAddText: ->
    text = 'Source'
    selectedIncidentCount = Template.instance().data.selectedIncidents?.fetch().length
    if selectedIncidentCount
      text = 'Incident'
    if selectedIncidentCount > 1
      text += 's'
    text

Template.addToEvent.events
  'click .add-to-event': (event, instance) ->
    userEventId = instance.selectedEventId.get()
    instanceData = instance.data
    source = instanceData.source
    selectedIncidents = instanceData.selectedIncidents
    if selectedIncidents?.count()
      selectedIncidentIds = _.pluck(selectedIncidents.fetch(), 'id')
      Meteor.call 'addIncidentsToEvent', selectedIncidentIds, userEventId, source, (error, result) ->
        if error
          notify('error', error.reason)
        else
          notify('success', 'Incident reports successfuly added to event')
    else
      sourceId = source._sourceId
      Meteor.call 'addEventSource',
        sourceId: sourceId
        url: "promedmail.org/post/#{sourceId}"
        userEventId: userEventId
        title: source.title
        publishDate: source.publishDate
        publishDateTZ: 'EST'
      , (error) ->
        if error
          notify('error', error.reason)
        else
          notify('success', 'Source successfuly added to event')

  'select2:select': (event, instance) ->
    instance.selectedEventId.set(event.params.data.id)

  'select2:opening': (event, instance) ->
    instance.tableContentScrollable?.set(false)

  'select2:open': (event, instance) ->
    unless $('.select2-results__additional-options').length
      $('.select2-dropdown').addClass('select2-dropdown--with-additional-options')
      $('.select2-results').append(
        """
          <div class='select2-results__additional-options'>
            <button class='btn btn-default add-new-event'>Add New Event</a>
          </div>
        """
      )

  'select2:closing': (event, instance) ->
    instance.tableContentScrollable?.set(true)

Template.addToEvent.onDestroyed ->
  $(document).off('click', '.add-new-event')
