import Articles from '/imports/collections/articles'
import Feeds from '/imports/collections/feeds'
import createInlineDateRangePicker from '/imports/ui/inlineDateRangePicker'
import {
  formatLocation,
  keyboardSelect,
  removeSuggestedProperties,
  diseaseOptionsFn,
  speciesOptionsFn } from '/imports/utils'
import { getIncidentSnippet } from '/imports/ui/snippets'
import notify from '/imports/ui/notification'

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
  @incidentType = new ReactiveVar('caseCount')
  @dateRangeType = new ReactiveVar('day')
  @locations = new ReactiveVar([])
  @suggestedFields = incident?.suggestedFields or new ReactiveVar([])

  @incidentData =
    dateRange:
      type: 'day'

  if incident
    if incident.sourceFeed
      @subscribe('feeds', {_id: incident.sourceFeed})

    @incidentData = _.extend(@incidentData, incident)
    if incident.dateRange
      @incidentData.dateRange = incident.dateRange
      @dateRangeType.set(incident.dateRange.type)

    cases = @incidentData.cases
    deaths = @incidentData.deaths
    specify = @incidentData.specify
    if cases >= 0
      type = 'caseCount'
    else if deaths >= 0
      type = 'deathCount'
    else if specify
      type = 'specify'
    else
      type = 'caseCount'
    if @incidentData?.dateRange?.cumulative
      if type == 'caseCount'
        type = 'cumulativeCaseCount'
      else if type == 'deathCount'
        type = 'cumulativeDeathCount'
    if @incidentData.type
      type = @incidentData.type
    @incidentType.set(type)

    @incidentStatus.set(@incidentData.status or '')

    if @incidentData.locations
      @locations.set(@incidentData.locations.map (loc) ->
        id: loc.id
        text: formatLocation(loc)
        item: loc
      )

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
    @locations.get()
    Meteor.defer =>
      @$('#add-incident').parsley().reset()

  @autorun =>
    switch @incidentType.get()
      when 'activeCount' then @dateRangeType.set("day")
      when 'cumulativeCaseCount' then @dateRangeType.set("day")
      when 'cumulativeDeathCount' then @dateRangeType.set("day")

Template.incidentForm.helpers
  incidentData: ->
    Template.instance().incidentData

  incidentStatusChecked: (status) ->
    status is Template.instance().incidentStatus.get()

  articles: ->
    Template.instance().data.articles

  showCountForm: ->
    Template.instance().incidentType.get() in [
      'caseCount'
      'deathCount'
      'cumulativeCaseCount'
      'cumulativeDeathCount'
      'activeCount'
    ]

  showOtherForm: ->
    Template.instance().incidentType.get() is 'specify'

  showRangeTab: ->
    Template.instance().incidentType.get() in [
      'caseCount'
      'deathCount'
      'specify'
    ]

  dayTabClass: ->
    if Template.instance().dateRangeType.get() is 'day'
      'active'

  rangeTabClass: ->
    if Template.instance().dateRangeType.get() is 'precise'
      'active'

  selectedIncidentType: ->
    switch Template.instance().incidentType.get()
      when 'caseCount' then 'Case'
      when 'deathCount' then 'Death'
      when 'cumulativeCaseCount' then 'Case'
      when 'cumulativeDeathCount' then 'Death'
      when 'activeCount' then 'Case'

  suggestedField: (fieldName) ->
    Template.instance().isSuggestedField(fieldName)

  typeIsSelected: ->
    Template.instance().incidentType.get()

  typeIsNotSelected: ->
    not Template.instance().incidentType.get()

  diseaseOptionsFn: -> diseaseOptionsFn

  speciesOptionsFn: -> speciesOptionsFn

  document: ->
    incident = Template.instance().data.incident
    if incident
      return Articles.findOne(incident.articleId)

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

  addUrl: ->
    article = Articles.findOne(Template.instance().data.incident?.articleId)
    not article?.url and not article?.enhancements?.source

  incidentCount: ->
    instance = Template.instance()
    incidentTypes = ['caseCount', 'cumulativeCaseCount', 'activeCount']
    if instance.incidentType.get() in incidentTypes
      instance.incidentData.cases
    else
      instance.incidentData.deaths

  incidentSpecify: ->
    Template.instance().incidentData.specify

  incidentType: ->
    Template.instance().incidentType.get()

  incidentTypes: ->
    [
      id: 'caseCount'
      text: 'Case count'
    ,
      id: 'deathCount'
      text: 'Death count'
    ,
      id: 'cumulativeCaseCount'
      text: 'Cumulative case count'
    ,
      id: 'cumulativeDeathCount'
      text: 'Cumulative death count'
    ,
      id: 'activeCount'
      text: 'Active case count'
    ,
      id: 'specify'
      text: 'Other'
    ]

  isSelectedIncidentType: ->
    @id == Template.instance().incidentType.get()

  sourceFeed: ->
    Feeds.findOne(_id: Template.instance().incidentData.sourceFeed)

Template.incidentForm.events
  'change input[name=daterangepicker_start]': (event, instance) ->
    instance.$('#singleDatePicker').data('daterangepicker').clickApply()

  'click .status label, keyup .status label': (event, instance) ->
    removeSuggestedProperties(instance, ['status'])
    _selectInput(event, instance, 'incidentStatus')

  'change .type': (event, instance) ->
    removeSuggestedProperties(instance, ['cases', 'deaths'])
    instance.incidentType.set($(event.target).val())

  'keyup [name="count"]': (event, instance) ->
    removeSuggestedProperties(instance, ['cases', 'deaths'])

  'click .select2-selection': (event, instance) ->
    # Remove selected empty item
    firstItem = $('.select2-results__options').children().first()
    if firstItem[0]?.id is ''
      firstItem.remove()

  'mouseup .select2-selection': (event, instance) ->
    removeSuggestedProperties(instance, ['locations'])

  'click .single-date': (event, instance) ->
    removeSuggestedProperties(instance, ['dateRange'])
    instance.dateRangeType.set('day')

  'click .date-range': (event, instance) ->
    removeSuggestedProperties(instance, ['dateRange'])
    instance.dateRangeType.set('precise')

  'submit form': (event, instance) ->
    event.preventDefault()
    formValid = false
    if $(event.target).parsley().isValid()
      formValid = true
    instance.data.valid.set(formValid)

  'click .tabs a': (event, instance) ->
    instance.$(event.currentTarget).parent().tooltip('hide')
