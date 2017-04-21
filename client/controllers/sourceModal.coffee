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

Template.sourceModal.onCreated ->
  @tzIsSpecified = false
  @proMEDRegEx = /promedmail\.org\/post\/(\d+)/ig
  @selectedArticle = new ReactiveVar(@data)
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
    article = @selectedArticle.get()
    if article.url and not article.promedDate
      # Trigger input event on url field so datetime is updated
      @$('#article').trigger('input')

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

  suggested: (field) ->
    if field in Template.instance().suggestedFields.get()
      'suggested-minimal'

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

    enhance = form.enhance.checked
    Meteor.call 'addEventSource', source, (error, articleId) ->
      if error
        toastr.error error.reason
      else
        if enhance
          notify('success', 'Source successfully added')
          Modal.show 'suggestedIncidentsModal',
            userEventId: instance.data.userEventId
            article: Articles.findOne(articleId)
          stageModals(instance, instance.modals)
        else
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

  'input #article': (event, instance) ->
    value = event.currentTarget.value.trim()
    match = /promedmail\.org\/post\/(\d+)/ig.exec(value)
    if match
      articleId = Number(match[1])
      Meteor.call 'retrieveProMedArticle', articleId, (error, article) ->
        if article
          date = moment.utc(article.promedDate)
          # Aproximate DST for New York timezone
          daylightSavings = moment.utc("#{date.year()}-03-08") <= date
          daylightSavings = daylightSavings and moment.utc(
            date.year() + "-11-01") >= date
          tz = if daylightSavings then 'EDT' else 'EST'
          date = date.utcOffset(UTCOffsets[tz])
          instance.$('#publishDateTZ').val(tz)
          _setDatePicker(instance.datePicker, date)
          instance.$('#publishTime').data('DateTimePicker').date(date)
          suggestedFields = ['title', 'date', 'time']
          unless instance.selectedArticle.get().promedDate
            suggestedFields.push('url')
          instance.suggestedFields.set(suggestedFields)
          instance.selectedArticle.set(article)

  'click #suggested-articles li': (event, instance) ->
    event.preventDefault()
    instance.selectedArticle.set(@)

  'submit form': (event, instance) ->
    instance.formValid.set(not event.isDefaultPrevented())
    event.preventDefault()

  'change #publishDateTZ': (e, instance) ->
    instance.tzIsSpecified = true

  'dp.change #publishTime, change #publishDateTZ': (event, instance) ->
    removeSuggestedProperties(instance, ['time'])

  'keyup #article': (event, instance) ->
    removeSuggestedProperties(instance, ['url'])

  'apply.daterangepicker #publishDate': (event, instance) ->
    removeSuggestedProperties(instance, ['date'])

  'change input[name=daterangepicker_start]': (event, instance) ->
    removeSuggestedProperties(instance, ['date'])
    instance.datePicker.clickApply()

  'input input[name=title], input input[name=url]': (event, instance) ->
    removeSuggestedProperties(instance, [event.currentTarget.name])
