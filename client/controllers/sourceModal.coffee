import convertDate from '/imports/convertDate.coffee'
import createInlineDateRangePicker from '/imports/ui/inlineDateRangePicker.coffee'
import notify from '/imports/ui/notification'
import { stageModals } from '/imports/ui/modals'

import {
  UTCOffsets,
  cleanUrl,
  removeSuggestedProperties } from '/imports/utils.coffee'

_setDatePicker = (picker, date) ->
  picker.setStartDate(date)
  picker.clickApply()

_checkForPublishDate = (url, instance) ->
  match = /promedmail\.org\/post\/(\d+)/ig.exec(url)
  if match
    articleId = match[1]
    Meteor.call 'retrieveProMedArticle', articleId, (error, article) ->
      if article
        instance.unspecifiedPublishDate.set(false)
        date = moment.utc(article.promedDate)
        # Aproximate DST for New York timezone
        daylightSavings = moment.utc("#{date.year()}-03-08") <= date
        daylightSavings = daylightSavings and moment.utc(
          date.year() + "-11-01") >= date
        tz = if daylightSavings then 'EDT' else 'EST'
        _article = _.extend article,
          tz: tz
          date: date.utcOffset(UTCOffsets[tz])
          suggested: true
        instance.selectedArticle.set(_article)

Template.sourceModal.onCreated ->
  @formValid = new ReactiveVar(false)
  @suggestedFields = new ReactiveVar([])
  @unspecifiedPublishDate = new ReactiveVar(true)
  @suggest = @data.suggest
  @suggest ?= true
  @edit = false
  @tzIsSpecified = false
  @proMEDRegEx = /promedmail\.org\/post\/(\d+)/ig
  @selectedArticle = new ReactiveVar(@data.source)
  @articleOrigin = new ReactiveVar('url')
  @modals =
    currentModal:
      element: '#event-source'
      add: 'off-canvas--left'
      remove: 'fade'

  @clearSelectedArticle = (clearUrlInput=false) =>
    _setDatePicker(@datePicker, new Date())
    @$('#title').val('')
    @$('#publishTime').val('')
    if clearUrlInput
      input = '#article'
    else
      input = '#content'
    @$(input).val('')
    @selectedArticle.set({})

  if @data.source
    @edit = true
    if @data.source.publishDate
      @unspecifiedPublishDate.set(false)
      @timezoneFixedPublishDate = convertDate(
        @data.source.publishDate, 'local',
        UTCOffsets[@data.source.publishDateTZ])
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

  @$('#add-source').parsley()

  @autorun =>
    selectedArticle = @selectedArticle.get()
    if selectedArticle and selectedArticle.date
      { tz, date } = selectedArticle
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
      if @source?.publishDateTZ
        if @source.publishDateTZ is tzKey
          timezones[timezones.length-1].selected = true
      else if tzKey is defaultTimezone
        timezones[timezones.length-1].selected = true
    timezones

  title: ->
    article = Template.instance().selectedArticle.get()
    article?.title or article?.subject

  url: ->
    Template.instance().selectedArticle.get()?.url

  presentUrl: ->
    instance = Template.instance()
    instance.selectedArticle.get()?.url and instance.edit

  suggestedArticles: ->
    Template.instance().suggestedArticles.find()

  loadingArticles: ->
    Template.instance().loadingArticles.get()

  articleSelected: ->
    @subject is Template.instance().selectedArticle.get()?.subject

  editing: ->
    Template.instance().edit

  showSuggestedDocuments: ->
    instance = Template.instance()
    not instance.edit and instance.suggest

  suggested: (field) ->
    if field in Template.instance().suggestedFields.get()
      'suggested-minimal'

  originIsUrl: ->
    Template.instance().articleOrigin.get() is 'url'

  originIsText: ->
    Template.instance().articleOrigin.get() is 'text'

  showEnhanceOption: ->
    # instance = Template.instance()
    # not instance.data.edit and instance.suggest
    false

  showArticleInputs: ->
    not Template.instance().edit

  showContent: ->
    @source?.content

  specifiedPublishDate: ->
    not Template.instance().unspecifiedPublishDate.get()

  unspecifiedPublishDate: ->
    Template.instance().unspecifiedPublishDate.get()

Template.sourceModal.events
  'click .save-source': (event, instance) ->
    $form = instance.$('form')
    $form.submit()
    return unless instance.formValid.get()
    form = $form[0]
    source = {}
    if @source?._id
      source._id = @source._id
    if form.article?.value
      source.url = cleanUrl(form.article.value)
    if form.content?.value
      source.content = form.content.value
    if form.title?.value
      source.title = form.title.value
    if not instance.unspecifiedPublishDate.get()
      timePicker = instance.$('#publishTime').data('DateTimePicker')
      date = instance.datePicker.startDate
      time = timePicker.date()
      source.publishDateTZ = form.publishDateTZ.value
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
    if source._id
      Meteor.call 'updateEventSource', source, (error, result) ->
        if error
          notify('error', error.reason)
        else
          notify('success', 'Source successfully updated')
          stageModals(instance, instance.modals)
    else
      Meteor.call 'addEventSource', source, instance.data.userEventId, (error, articleId) ->
        if error
          notify('error', error.reason)
        else
          notify('success', 'Source successfully added')
          stageModals(instance, instance.modals)
          instance.data.selectedSourceId?.set(articleId)

  'input #article': _.debounce (event, instance) ->
      $('#content').val('')
      instance.unspecifiedPublishDate.set(true)
      url = event.target.value.trim()
      if url.length > 20 # Check if the length at url base length
        _checkForPublishDate(url, instance)
  , 200

  'input #content': (event, instance) ->
    $('#article').val('')
    if instance.selectedArticle.get()?.suggested
      instance.clearSelectedArticle(true)
      removeSuggestedProperties(instance, 'all')

  'click #suggested-articles li': (event, instance) ->
    instance.clearSelectedArticle()
    instance.articleOrigin.set('url')
    _checkForPublishDate(@url, instance)

  'submit form': (event, instance) ->
    instance.formValid.set($(event.target).parsley().isValid())
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

  'click .add-publish-date button': (event, instance)->
    instance.unspecifiedPublishDate.set(false)
