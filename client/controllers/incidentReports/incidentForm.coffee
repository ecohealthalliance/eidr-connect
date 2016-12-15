createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'

_keyboardSelect = (event) ->
  keyCode = event.keyCode
  keyCode in [13, 32]

_selectInput = (event, instance, prop, isCheckbox) ->
  return if not _keyboardSelect(event) and event.type is 'keyup'
  if isCheckbox is 'checkbox'
    prop = instance[prop]
    prop.set(not prop.get())
  else
    instance[prop].set(instance.$(event.target).attr('for'))

Template.incidentForm.onCreated ->
  @incidentStatus = new ReactiveVar ''
  @incidentType = new ReactiveVar ''
  @cumulative = new ReactiveVar false
  @travelRelated = new ReactiveVar false

  @incidentData =
    species: 'Human'
    dateRange:
      type: 'day'

  incident = @data.incident
  if incident
    @incidentData = _.extend(@incidentData, incident)
    if incident.dateRange
      @incidentData.dateRange = incident.dateRange

    cases = @incidentData.cases
    deaths = @incidentData.deaths
    specify = @incidentData.specify
    @incidentData.value = cases or deaths or specify
    if cases
      type = 'cases'
    else if deaths
      type = 'deaths'
    else if specify
      type = 'other'
    else
      type = ''

    @incidentType.set(type)

    if @incidentData.url
      @incidentData.articleSource = _.findWhere(@data.articles,
        url: @incidentData.url[0]
      )?._id

    @incidentStatus.set(incident.status or '')
    @cumulative.set(incident.cumulative or false)
    @travelRelated.set(incident.travelRelated or false)

Template.incidentForm.onRendered ->
  datePickerOptions = {}
  if @incidentData.dateRange.start and @incidentData.dateRange.end
    datePickerOptions.startDate = @incidentData.dateRange.start
    datePickerOptions.endDate = @incidentData.dateRange.end
  createInlineDateRangePicker(@$('#rangePicker'), datePickerOptions)
  datePickerOptions.singleDatePicker = true
  createInlineDateRangePicker(@$('#singleDatePicker'), datePickerOptions)

Template.incidentForm.helpers
  incidentData: ->
    Template.instance().incidentData

  incidentStatusChecked: (status) ->
    status is Template.instance().incidentStatus.get()

  incidentTypeChecked: (type) ->
    type is Template.instance().incidentType.get()

  articles: ->
    Template.instance().data.articles

  showCountForm: ->
    type = Template.instance().incidentType.get()
    type is 'cases' or type is 'deaths'

  showOtherForm: ->
    Template.instance().incidentType.get() is 'other'

  dayTabClass: ->
    if Template.instance().incidentData.dateRange.type is 'day'
      'active'

  rangeTabClass: ->
    if Template.instance().incidentData.dateRange.type is 'precise'
      'active'

  cumulative: ->
    Template.instance().cumulative.get()

  travelRelated: ->
    Template.instance().travelRelated.get()

  selectedIncidentType: ->
    Template.instance().incidentType.get().slice(0, -1)

Template.incidentForm.events
  'change input[name=daterangepicker_start]': (event, instance) ->
    instance.$('#singleDatePicker').data('daterangepicker').clickApply()

  'click .status label, keyup .status label': (event, instance) ->
    _selectInput(event, instance, 'incidentStatus')

  'click .type label, keyup .type label': (event, instance) ->
    _selectInput(event, instance, 'incidentType')

  'click .travel-related, keyup .travel-related': (event, instance) ->
    _selectInput(event, instance, 'travelRelated', true)

  'click .cumulative, keyup .cumulative': (event, instance) ->
    _selectInput(event, instance, 'cumulative', true)

  'click .select2-selection': (event, instance) ->
    # Remove selected empty item
    firstItem = $('.select2-results__options').children().first()
    if firstItem[0]?.id is ''
      firstItem.remove()
