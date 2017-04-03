Template.extractIncidents.onCreated ->
  @source = new ReactiveVar 'text'
  @submitDisabled = new ReactiveVar true

Template.extractIncidents.onRendered ->
  @autorun =>
    source = @source.get()
    if source is 'url' and not @$('.submit-url').val()
      @submitDisabled.set true
    else if source is 'text' and not @$('textarea').val()
      @submitDisabled.set true
    else
      @submitDisabled.set false

Template.extractIncidents.helpers
  submitDisabled: ->
    Template.instance().submitDisabled.get()

Template.extractIncidents.events
  'click .upload-menu a': (event, instance) ->
    instance.source.set($(event.target).data('source'))
    instance.$(event.currentTarget).blur()

  'input textarea, input .submit-url': (event, instance) ->
    if instance.$(event.target).val()
      instance.submitDisabled.set false
    else
      instance.submitDisabled.set true

  "click #submit-button": (event, instance) ->
    if instance.source.get() is 'url'
      url = $('#submit-url').val()
      if !/^(f|ht)tps?:\/\//i.test(url)
        url = 'http://' + url
      content = null
    else
      content = $('#submit-text').val()
      url = null

    Modal.show 'suggestedIncidentsModal',
      userEventId: null
      showTable: true
      acceptByDefault: true
      offCanvasStartPosition: 'top'
      classNames: 'extracted'
      article:
        publishDate: new Date()
        addedDate: new Date()
        url: url
        content: content
