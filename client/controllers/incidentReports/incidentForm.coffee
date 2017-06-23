import Articles from '/imports/collections/articles.coffee'
import createInlineDateRangePicker from '/imports/ui/inlineDateRangePicker.coffee'
import validator from 'bootstrap-validator'
import {
  keyboardSelect,
  removeSuggestedProperties,
  diseaseOptionsFn } from '/imports/utils'
import { getIncidentSnippet } from '/imports/ui/snippets'

_selectInput = (event, instance, prop, isCheckbox) ->
  return if not keyboardSelect(event) and event.type is 'keyup'
  if isCheckbox is 'checkbox'
    prop = instance[prop]
    prop.set(not prop.get())
  else
    clickedInput = instance.$(event.target).attr('for')
    state = instance[prop]
    if state.get() is clickedInput
      state.set(null)
    else
      state.set(clickedInput)

Template.incidentForm.onCreated ->
  instanceData = @data
  incident = instanceData.incident
  articleId = incident?.articleId
  if articleId
    @subscribe 'incidentArticle', articleId
  @incidentStatus = new ReactiveVar('')
  @incidentType = new ReactiveVar('')
  @locations = new ReactiveVar([])
  @suggestedFields = incident?.suggestedFields or new ReactiveVar([])

  @incidentData =
    species: 'Human'
    dateRange:
      type: 'day'

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

    @incidentStatus.set(@incidentData.status or '')

  @isSuggestedField = (fieldName) =>
    if fieldName in @suggestedFields?.get()
      'suggested'

Template.incidentForm.onRendered ->
  @$('[data-toggle=tooltip]').tooltip
    container: 'body'
  datePickerOptions = {}
  if @incidentData.dateRange.start and @incidentData.dateRange.end
    datePickerOptions.startDate = moment(moment.utc(@incidentData.dateRange.start).format("YYYY-MM-DD"))
    datePickerOptions.endDate = moment(moment.utc(@incidentData.dateRange.end).format("YYYY-MM-DD"))
  createInlineDateRangePicker(@$('#rangePicker'), datePickerOptions)
  datePickerOptions.singleDatePicker = true
  createInlineDateRangePicker(@$('#singleDatePicker'), datePickerOptions)

  @$('#add-incident').parsley()
  #Update the validator when Blaze adds incident type related inputs
  @autorun =>
    @incidentType.get()
    @locations.get()
    Meteor.defer =>
      @$('#add-incident').parsley().reset()

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

  selectedIncidentType: ->
    switch Template.instance().incidentType.get()
      when 'cases' then 'Case'
      when 'deaths' then 'Death'

  suggestedField: (fieldName) ->
    Template.instance().isSuggestedField(fieldName)

  typeIsSelected: ->
    Template.instance().incidentType.get()

  typeIsNotSelected: ->
    not Template.instance().incidentType.get()

  diseaseOptionsFn: -> diseaseOptionsFn

  documentUrl: ->
    incident = Template.instance().data.incident
    if incident
      return Articles.findOne(incident.articleId)?.url

  documentId: ->
    Template.instance().data.incident?.articleId

  incidentTypeClassNames: ->
    classNames = []
    instance = Template.instance()
    if Template.instance().incidentType.get()
      classNames.push('form-groups--highlighted')
    classNames.push(instance.isSuggestedField('cases'))
    classNames.push(instance.isSuggestedField('deaths'))
    classNames.join(' ')

  incidentSnippet: ->
    incident = @incident
    if incident?.annotations
      article = Articles.findOne(@articleId)
      articleContent = article?.enhancements?.source.cleanContent.content
      if articleContent
        Spacebars.SafeString(getIncidentSnippet(articleContent, incident))

  locations: -> Template.instance().locations

Template.incidentForm.events
  'change input[name=daterangepicker_start]': (event, instance) ->
    instance.$('#singleDatePicker').data('daterangepicker').clickApply()

  'click .status label, keyup .status label': (event, instance) ->
    removeSuggestedProperties(instance, ['status'])
    _selectInput(event, instance, 'incidentStatus')

  'click .type label, keyup .type label': (event, instance) ->
    removeSuggestedProperties(instance, ['cases', 'deaths'])
    _selectInput(event, instance, 'incidentType')

  'keyup [name="count"]': (event, instance) ->
    removeSuggestedProperties(instance, ['cases', 'deaths'])

  'click .select2-selection': (event, instance) ->
    # Remove selected empty item
    firstItem = $('.select2-results__options').children().first()
    if firstItem[0]?.id is ''
      firstItem.remove()

  'mouseup .select2-selection': (event, instance) ->
    removeSuggestedProperties(instance, ['locations'])

  'mouseup .incident--dates': (event, instance) ->
    removeSuggestedProperties(instance, ['dateRange'])

  'click .cumulative, keyup .cumulative': (event, instance) ->
    removeSuggestedProperties(instance, ['cumulative'])

  'submit form': (event, instance) ->
    event.preventDefault()
    formValid = false
    if $(event.target).parsley().isValid()
      formValid = true
    instance.data.valid.set(formValid)

  'click .tabs a': (event, instance) ->
    instance.$(event.currentTarget).parent().tooltip('hide')
