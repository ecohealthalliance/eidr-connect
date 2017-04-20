convertDate = require '/imports/convertDate.coffee'
Articles = require '/imports/collections/articles.coffee'
createInlineDateRangePicker = require '/imports/ui/inlineDateRangePicker.coffee'
validator = require 'bootstrap-validator'
{ notify } = require '/imports/ui/notification'
{ stageModals } = require '/imports/ui/modals'

import {
  UTCOffsets,
  cleanUrl,
  removeSuggestedProperties } from '/imports/utils.coffee'

_checkFormValidity = (instance) ->
  $form = instance.$('form')
  $form.validator('validate')
  $form.submit()
  instance.formValid.get()

_setDatePicker = (picker, date) ->
  picker.setStartDate(date)
  picker.clickApply()

_checkForPublishDate = (url, instance) ->
  match = /promedmail\.org\/post\/(\d+)/ig.exec(url)
  if match
    articleId = match[1]
    Meteor.call 'retrieveProMedArticle', articleId, (error, article) ->
      if article
        date = moment.utc(article.promedDate)
        # Aproximate DST for New York timezone
        daylightSavings = moment.utc("#{date.year()}-03-08") <= date
        daylightSavings = daylightSavings and moment.utc(
          date.year() + "-11-01") >= date
        tz = if daylightSavings then 'EDT' else 'EST'
        _article = _.extend article,
          tz: tz
          date: date.utcOffset(UTCOffsets[tz])
        instance.selectedArticle.set(_article)

Template.sourceModal.onCreated ->
  @suggest = @data.suggest
  @suggest ?= true
  @tzIsSpecified = false
  @proMEDRegEx = /promedmail\.org\/post\/(\d+)/ig
  @selectedArticle = new ReactiveVar(@data)
  @articleOrigin = new ReactiveVar('url')
  @modals =
    currentModal:
      element: '#event-source'
      add: 'off-canvas--left'
      remove: 'fade'

  if @data.edit
    if @data.publishDate
      @timezoneFixedPublishDate = convertDate(@data.publishDate, 'local',
                                                UTCOffsets[@data.publishDateTZ])
  else
    @loadingArticles = new ReactiveVar(true)
    @suggestedArticles = new Mongo.Collection(null)
    Meteor.call 'queryForSuggestedArticles', @data.userEventId, (error, result) =>
      @loadingArticles.set(false)
      if result
        for suggestedArticle in result
          @suggestedArticles.insert
            url: "http://www.promedmail.org/post/#{suggestedArticle.promedId}"
            subject: suggestedArticle.subject.raw

Template.sourceModal.onCreated ->
  @formValid = new ReactiveVar(false)
  @suggestedFields = new ReactiveVar([])

Template.sourceModal.onRendered ->
  publishDate = @timezoneFixedPublishDate
  pickerOptions =
    singleDatePicker: true
  if publishDate
    pickerOptions.startDate = publishDate
  @datePicker = createInlineDateRangePicker(@$('#publishDate'), pickerOptions)

  pickerOptions =
    format: 'h:mm A'
    useCurrent: false
    defaultDate:  publishDate or false
  @$('.timePicker').datetimepicker(pickerOptions)

  @$('#add-source').validator()

  @autorun =>
    { tz, date } = @selectedArticle.get()
    if date
      @$('#publishDateTZ').val(tz)
      @$('#publishTime').data('DateTimePicker').date(date)
      _setDatePicker(@datePicker, date)
      @suggestedFields.set(['title', 'date', 'time', 'url'])

Template.sourceModal.helpers
  timezones: ->
    timezones = []
    defaultTimezone = if moment().isDST() then 'EDT' else 'EST'
    for tzKey, tzOffset of UTCOffsets
      timezones.push({name: tzKey, offset: tzOffset})
      if @publishDateTZ
        if @publishDateTZ is tzKey
          timezones[timezones.length-1].selected = true
      else if tzKey is defaultTimezone
        timezones[timezones.length-1].selected = true
    timezones

  saveButtonClass: ->
    if @edit
      'save-source-edit'
    else
      'save-source'

  title: ->
    article = Template.instance().selectedArticle.get()
    article.title or article.subject

  url: ->
    Template.instance().selectedArticle.get().url

  suggestedArticles: ->
    Template.instance().suggestedArticles.find()

  loadingArticles: ->
    Template.instance().loadingArticles.get()

  articleSelected: ->
    @subject is Template.instance().selectedArticle.get().subject

  editing: ->
    Template.instance().data.edit

  showSuggestedDocuments: ->
    instance = Template.instance()
    not instance.data.edit and instance.suggest

  suggested: (field) ->
    if field in Template.instance().suggestedFields.get()
      'suggested-minimal'

  originIsUrl: ->
    Template.instance().articleOrigin.get() is 'url'

  originIsText: ->
    Template.instance().articleOrigin.get() is 'text'

  showEnhanceOption: ->
    instance = Template.instance()
    not instance.data.edit and instance.suggest

Template.sourceModal.events
  'click .save-source': (event, instance) ->
    return unless _checkFormValidity(instance)
    form = instance.$('form')[0]
    article = form.article.value
    validURL = form.article.checkValidity()
    timePicker = instance.$('#publishTime').data('DateTimePicker')
    date = instance.datePicker.startDate
    time = timePicker.date()

    source =
      userEventId: instance.data.userEventId
      url: cleanUrl(article)
      content: form.content.value
      publishDateTZ: form.publishDateTZ.value
      title: form.title.value

    if date
      selectedDate = moment
        year: date.year()
        month: date.month()
        date: date.date()
      if form.publishTime.value.length
        selectedDate.set({hour: time.get('hour'), minute: time.get('minute')})
        selectedDate = convertDate(selectedDate,
                                    UTCOffsets[source.publishDateTZ], 'local')
      source.publishDate = selectedDate.toDate()

    enhance = form.enhance?.checked
    Meteor.call 'addEventSource', source, (error, articleId) ->
      if error
        toastr.error error.reason
      else
        if enhance and instance.suggest
          notify('success', 'Source successfully added')
          instance.subscribe 'ArticleIncidentReports', articleId
          Modal.show 'suggestedIncidentsModal',
            userEventId: instance.data.userEventId
            article: source
          stageModals(instance, instance.modals)
        else
          instance.data.selectedSourceId?.set(articleId)
          Modal.hide(instance)

  'click .save-source-edit': (event, instance) ->
    return unless _checkFormValidity(instance)
    form = instance.$('form')[0]
    timePicker = instance.$('#publishTime').data('DateTimePicker')
    date = instance.datePicker.startDate
    time = timePicker.date()

    source = @
    source.publishDateTZ = form.publishDateTZ.value
    source.title = form.title.value

    if date
      selectedDate = moment
        year: date.year()
        month: date.month()
        date: date.date()
      if form.publishTime.value.length
        selectedDate.set
          hour: time.get('hour')
          minute: time.get('minute')
        selectedDate = convertDate(selectedDate,
                                    UTCOffsets[source.publishDateTZ], 'local')
      source.publishDate = selectedDate.toDate()

    Meteor.call 'updateEventSource', source, (error, result) ->
      if error
        toastr.error error.reason
      else
        stageModals(instance, instance.modals)

  'input #article': _.debounce (event, instance) ->
      url = event.target.value.trim()
      if url.length > 20 # Check if the length at url base length
        _checkForPublishDate(url, instance)
  , 200

  'click #suggested-articles li': (event, instance) ->
    _checkForPublishDate(@url, instance)

  'submit form': (event, instance) ->
    instance.formValid.set(not event.isDefaultPrevented())
    event.preventDefault()

  'change #publishDateTZ': (e, instance) ->
    instance.tzIsSpecified = true

  'click #publishTime, click #publishDateTZ': (event, instance) ->
    removeSuggestedProperties(instance, ['time'])

  'keyup #article': (event, instance) ->
    removeSuggestedProperties(instance, ['url'])

  'click #publishDate': (event, instance) ->
    removeSuggestedProperties(instance, ['date'])

  'click input[name=daterangepicker_start]': (event, instance) ->
    removeSuggestedProperties(instance, ['date'])
    instance.datePicker.clickApply()

  'click input[name=title], click input[name=url]': (event, instance) ->
    removeSuggestedProperties(instance, [event.currentTarget.name])

  'click .tabs li a': (event, instance) ->
    instance.articleOrigin.set($(event.currentTarget).attr('href').slice(1))
