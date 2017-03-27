UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
{ notify } = require '/imports/ui/notification'

select2NoResults = ->
  """
    <div class='no-results small'>
      <p>No Results Found</p>
    </div>
    <button class='btn btn-default add-new-event'>Add New Event</a>
  """

Template.addToEvent.onCreated ->
  @subscribe('userEvents')
  @subscribe('article', @data.source._sourceId)
  @selectedEventId = new ReactiveVar(null)

Template.addToEvent.onRendered ->
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
      language:
        noResults: select2NoResults
      escapeMarkup: (markup) -> markup

    $(document).on 'click', '.add-new-event', (event) =>
      $select2.select2('close')
      Modal.show 'editEventDetailsModal',
        action: 'add'
        saveActionMessage: 'Add Event & Associate Incident Reports'
        sourceId: @data.sourceId
        eventName: ''

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
    source = instance.data.source
    unless Articles.findOne(url: $regex: new RegExp("#{source._sourceId}$"))
      Meteor.call 'addEventSource',
        url: "promedmail.org/post/#{source._sourceId}"
        userEventId: userEventId
        title: source.title
        publishDate: source.publishDate
        publishDateTZ: 'EST'

    selectedIncidents = instance.data.selectedIncidents
    if selectedIncidents
      selectedIncidentIds = _.pluck(selectedIncidents.fetch(), 'id')
      Meteor.call 'addIncidentsToEvent', selectedIncidentIds, userEventId, (error, result) ->
        if error
          notify('error', error.reason)
        else
          notify('success', 'Incident reports successfuly added to event')

  'select2:select': (event, instance) ->
    instance.selectedEventId.set(event.params.data.id)

  'select2:opening': (event, instance) ->
    instance.tableContentScrollable?.set(false)

  'select2:closing': (event, instance) ->
    instance.tableContentScrollable?.set(true)

Template.addToEvent.onDestroyed ->
  $(document).off('click', '.add-new-event')
