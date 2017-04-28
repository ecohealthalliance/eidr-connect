Articles = require '/imports/collections/articles.coffee'
createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'
validator = require 'bootstrap-validator'
{ keyboardSelect, removeSuggestedProperties, diseaseOptionsFn } = require '/imports/utils'
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
  @suggestedFields = incident?.suggestedFields or new ReactiveVar([])

  @incidentData =
    species: 'Human'
    dateRange:
      type: 'day'

  article = instanceData.articles[0]
  if article
    @incidentData.articleId = article._id

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

    @incidentStatus.set(incident.status or '')

  @isSuggestedField = (fieldName) =>
    if fieldName in @suggestedFields?.get()
      'suggested'

Template.incidentForm.onRendered ->
  @$('[data-toggle=tooltip]').tooltip()
  datePickerOptions = {}
  if @incidentData.dateRange.start and @incidentData.dateRange.end
    datePickerOptions.startDate = moment(moment.utc(@incidentData.dateRange.start).format("YYYY-MM-DD"))
    datePickerOptions.endDate = moment(moment.utc(@incidentData.dateRange.end).format("YYYY-MM-DD"))
  createInlineDateRangePicker(@$('#rangePicker'), datePickerOptions)
  datePickerOptions.singleDatePicker = true
  createInlineDateRangePicker(@$('#singleDatePicker'), datePickerOptions)

  @$('#add-incident').validator()
  #Update the validator when Blaze adds incident type related inputs
  @autorun =>
    @incidentType.get()
    Meteor.defer =>
      @$('#add-incident').validator('update')

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

  articleSourceUrl: ->
    Template.instance().data.articles[0]?.url

  diseaseOptionsFn: -> diseaseOptionsFn

  documentUrl: ->
    Articles.findOne(Template.instance().data.incident?.articleId)?.url

  allowUrlInput: ->
    not @edit and not @articleId

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
    if incident
      articleContent = Articles.findOne(incident.articleId)?.enhancements?.source?.cleanContent.content
      if articleContent
        Spacebars.SafeString(getIncidentSnippet(articleContent, incident))

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
    prevented = event.isDefaultPrevented()
    instance.data.valid.set(not prevented)
    if prevented
      # Toggle focus on location input so 'has-error' class is applied
      if not instance.$('.select2-selection__choice').length
        instance.$('.select2-search__field').blur()
        instance.$('.has-error:first-child').focus()
    event.preventDefault()

  'click .tabs a': (event, instance) ->
    instance.$(event.currentTarget).parent().tooltip('hide')
