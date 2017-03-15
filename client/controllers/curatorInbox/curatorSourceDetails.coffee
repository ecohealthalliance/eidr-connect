CuratorSources = require '/imports/collections/curatorSources.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
key = require 'keymaster'
{ notify } = require '/imports/ui/notification'
{ annotateContent } = require('/imports/ui/annotation')

_markReviewed = (instance, showNext=true) ->
  new Promise (resolve) ->
    reviewed = instance.reviewed
    notifying = instance.notifying
    reviewed.set not reviewed.get()
    Meteor.call('markSourceReviewed', instance.source.get()._id, reviewed.get())
    if reviewed.get()
      notifying.set true
      Meteor.setTimeout ->
        if showNext
          unReviewedQuery = $and: [ {reviewed: false}, instance.data.query.get()]
          nextSource = CuratorSources.findOne unReviewedQuery,
            sort:
              publishDate: -1
          instance.data.selectedSourceId.set nextSource._id
        notifying.set false
        resolve()
      , 1200

Template.curatorSourceDetails.onCreated ->
  @notifying = new ReactiveVar(false)
  @source = new ReactiveVar(null)
  @reviewed = new ReactiveVar(false)
  @incidentsLoaded = new ReactiveVar(true)

Template.curatorSourceDetails.onRendered ->
  instance = @
  Meteor.defer =>
    instance.$('[data-toggle=tooltip]').tooltip
      delay: show: '300'
      container: 'body'
    if window.innerWidth <= 1000
      Hamer = require 'hammerjs'
      swippablePane = new Hammer($('#touch-stage')[0])
      swippablePane.on 'swiperight', (event) ->
        instance.data.currentPaneInView.set('')

  # Create key binding which marks sources as reviewed.
  key 'ctrl + enter, command + enter', (event) =>
    _markReviewed(@)

  @autorun =>
    # When source is selected in the curatorInbox template, `selectedSourceId`,
    # which is handed down, is updated and triggers this autorun
    # current source
    sourceId = @data.selectedSourceId.get()
    source = CuratorSources.findOne(sourceId)
    instance.reviewed.set source?.reviewed or false
    instance.source.set source

  @autorun =>
    source = @source.get()
    if source
      @incidentsLoaded.set(false)
      title = source.title
      sourceId = source._sourceId
      # Update the source title and its tooltip in the right pane
      Meteor.defer =>
        $title = $('#sourceDetailsTitle')
        titleEl = $title[0]
        # Remove title and tooltip if the title is complete & without ellipsis
        if titleEl.offsetWidth >= titleEl.scrollWidth
          $title.tooltip('hide').attr('data-original-title', '')
        else
          $title.attr('data-original-title', title)

      @subscribe 'curatorSourceIncidentReports', sourceId,
        onReady: =>
          source.url = "http://www.promedmail.org/post/#{sourceId}"
          if Incidents.findOne(url: $regex: new RegExp("#{sourceId}$"))
            instance.incidentsLoaded.set(true)
          else
            Meteor.call 'getArticleEnhancements', source, (error, enhancements) =>
              if error
                notify('error', error.reason)
              else
                options =
                  enhancements: enhancements
                  source: source
                  acceptByDefault: true
                  addToCollection: true
                Meteor.call 'createIncidentReportsFromEnhancements', options, (error, result) ->
                  instance.incidentsLoaded.set(true)

Template.curatorSourceDetails.helpers
  source: ->
    Template.instance().source.get()

  formattedScrapeDate: ->
    moment(Template.instance().data.sourceDate).format('MMMM DD, YYYY')

  formattedPromedDate: ->
    moment(Template.instance().data.promedDate).format('MMMM DD, YYYY')

  isReviewed: ->
    Template.instance().source.get().reviewed

  notifying: ->
    Template.instance().notifying.get()

  selectedSourceId: ->
    Template.instance().data.selectedSourceId

  incidentsLoaded: ->
    Template.instance().incidentsLoaded.get()

  annotatedContent: ->
    incidents = Incidents.find().fetch()
    if incidents.length
      annotateContent(@content, incidents)

Template.curatorSourceDetails.events
  "click .toggle-reviewed": (event, instance) ->
    _markReviewed(instance)

  'click .back-to-list': (event, instance) ->
    instance.data.currentPaneInView.set('')
