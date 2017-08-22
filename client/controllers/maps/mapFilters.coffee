import createInlineDateRangePicker from '/imports/ui/inlineDateRangePicker'
import { setVariables } from '/imports/ui/setRange'

Template.mapFilters.onCreated ->
  @dateVariables = new ReactiveVar
    searchType: 'on'
    dates: []
  @userSearchText = new ReactiveVar ''
  @filtering = new ReactiveVar false
  @calendarState = new ReactiveVar false

Template.mapFilters.onRendered ->
  instance = @
  @autorun ->
    checkValues = Template.instance().dateVariables.get()
    filters = []
    if instance.filtering.get()
      varQuery = {}
      if checkValues.dates.length
        startFilterDate = checkValues.dates[0]
        endFilterDate = checkValues.dates[1]
        filters.push(
          $and: [
            {
              lastIncidentDate: $gte: startFilterDate
            }, {
              lastIncidentDate: $lte: endFilterDate
            }
          ]
        )

    userSearchText = instance.userSearchText.get().$regex
    if userSearchText
      instance.data.selectedEvents.remove({})
      nameQuery = []
      searchWords = userSearchText.split(' ')
      _.each searchWords, ->
        nameQuery.push {eventName: new RegExp(userSearchText, 'i')}
      filters.push $or: nameQuery

    if filters.length
      instance.data.query.set({ $and: filters })
    else
      instance.data.query.set({})

Template.mapFilters.helpers
  dateVariables: ->
    Template.instance().dateVariables

  getSearchText: ->
    Template.instance().userSearchText.get()

  searchMatch: (matchType, valueType) ->
    matchType is valueType

  getEvents: ->
    Template.instance().data.templateEvents?.get()

  disablePrev: ->
    Template.instance().data.disablePrev?.get()

  disableNext: ->
    Template.instance().data.disableNext?.get()

  filtering: ->
    Template.instance().filtering

  selected: ->
    Template.instance().data.selectedEvents.findOne(_id: @_id)

  eventsAreSelected: ->
    Template.instance().data.selectedEvents.findOne()

  calendarState: ->
    Template.instance().calendarState.get()

  searchSettings: ->
    id: 'mapFilters'
    textFilter: Template.instance().userSearchText
    placeholder: 'Search events'

Template.mapFilters.events
  'cancel.daterangepicker': (e, instance) ->
    $(e.target).val("")
    setVariables instance, 'on', []

  'click .map-event-list--item': (event, instance) ->
    selectedEvents = instance.data.selectedEvents
    _id = @_id
    if selectedEvents.findOne(_id: _id)
      selectedEvents.remove(_id: _id)
    else
      userEvent = _.find(instance.data.templateEvents.get(), (e) -> e._id == _id)
      selectedEvents.insert
        _id: _id
        rgbColor: @rgbColor
        eventName: userEvent.eventName
        selected: true
        incidents: userEvent.incidents

  'click .toggle-calendar-state': (e, instance) ->
    calendarState = instance.calendarState
    calendarState.set not calendarState.get()

  'click .deselect-all': (e, instance) ->
    instance.data.selectedEvents.remove({})
