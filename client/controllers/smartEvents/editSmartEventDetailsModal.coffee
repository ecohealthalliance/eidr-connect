{ dismissModal } = require('/imports/ui/modals')
{ notify } = require('/imports/ui/notification')
createInlineDateRangePicker = require('/imports/ui/inlineDateRangePicker')
{ updateCalendarSelection } = require('/imports/ui/setRange')
require('bootstrap-validator')
{ diseaseOptionsFn } = require '/imports/utils'

Template.editSmartEventDetailsModal.onCreated ->
  @confirmingDeletion = new ReactiveVar(false)
  @addDate = new ReactiveVar(false)

Template.editSmartEventDetailsModal.onRendered ->
  if @data.dateRange
    @addDate.set(true)
  @autorun =>
    if @addDate.get()
      Meteor.defer =>
        $pickerEl = $("#date-picker")
        createInlineDateRangePicker($pickerEl)
        @calendar = $pickerEl.data('daterangepicker')
        instanceData = @data
        dateRange = instanceData.dateRange
        if dateRange
          range =
            startDate: dateRange.start
            endDate: dateRange.end
          updateCalendarSelection(@calendar, range)
  Meteor.defer =>
    @$('#editEvent').validator
      # Do not disable inputs since we don't in other areas of the app
      disable: false

Template.editSmartEventDetailsModal.helpers
  confirmingDeletion: ->
    Template.instance().confirmingDeletion.get()

  adding: ->
    Template.instance().data?.action is 'add'

  showAddDateButton: ->
    not Template.instance().addDate.get()

  showCalendar: ->
    Template.instance().addDate.get()

  diseaseOptionsFn: -> diseaseOptionsFn

Template.editSmartEventDetailsModal.events
  'submit #editEvent': (event, instance) ->
    form = event.target
    return if event.isDefaultPrevented() # Form is invalid
    event.preventDefault()

    diseases = $(form)
    .find('#disease-select2')
    .select2('data')
    .map (option)->
      id: option.id
      text: option?.item?.label or option.text

    smartEvent =
      _id: @_id
      eventName: form.eventName.value.trim()
      summary: form.eventSummary.value.trim()
      diseases: diseases

    # Locations
    locations = []
    $locationsEl = instance.$('#event-locations')
    for option in $locationsEl.select2('data')
      item = option.item
      if typeof item.alternateNames is 'string'
        delete item.alternateNames
      locations.push(item)
    smartEvent.locations = locations

    # Daterange
    calendar = instance.calendar
    if calendar
      smartEvent.dateRange =
        start: calendar.startDate.toDate()
        end: calendar.endDate.toDate()

    Meteor.call 'upsertSmartEvent', smartEvent, (error, {insertedId}) ->
      if error
        notify('error', error.message)
      else
        adding = instance.data.action is 'add'
        action = 'updated'
        dismissModal(instance.$('#smart-event-modal')).then ->
        if adding
          action = 'added'
          Router.go('smart-event', _id: insertedId)
        notify('success', "Smart event #{action}")

  'click .delete-event': (event, instance) ->
    instance.confirmingDeletion.set true

  'click .back-to-editing': (event, instance) ->
    instance.confirmingDeletion.set false

  'click .add-date': (event, instance) ->
    instance.addDate.set(true)
