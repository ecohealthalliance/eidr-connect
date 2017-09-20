import Articles from '/imports/collections/articles.coffee'
import Incidents from '/imports/collections/incidentReports.coffee'
import UserEvents from '/imports/collections/userEvents.coffee'
import key from 'keymaster'
import notify from '/imports/ui/notification'
import Hammer from 'hammerjs'


Template.curatorSourceDetails.onCreated ->
  @selectedIncidents = new Meteor.Collection(null)
  @notifying = new ReactiveVar(false)
  @reviewed = new ReactiveVar(false)
  @incidentsLoaded = new ReactiveVar(false)
  @addingSourceToEvent = new ReactiveVar(false)
  @selectedAnnotationId = new ReactiveVar(null)
  @selectedSourceId = @data.selectedSourceId

  @markReviewed = (showNext=true) =>
    new Promise (resolve) =>
      instanceData = @data
      reviewed = @reviewed
      reviewed.set(not reviewed.get())
      Meteor.call('markSourceReviewed', @selectedSourceId.get(), reviewed.get())
      if reviewed.get()
        @notifying.set(true)
        setTimeout =>
          if showNext
            $(@firstNode).trigger('sourceReviewed')
          @notifying.set(false)
          resolve()
        , 1200

Template.curatorSourceDetails.onRendered ->
  Meteor.defer =>
    if window.innerWidth <= 1000
      swippablePane = new Hammer($('#touch-stage')[0])
      swippablePane.on 'swiperight', (event) ->
        @data.currentPaneInView.set('')

  # Create key binding which marks documents as reviewed.
  key 'ctrl + enter, command + enter', (event) =>
    @markReviewed()

  @autorun =>
    # When document is selected in the curatorInbox template, `selectedSourceId`,
    # which is handed down, is updated and triggers this autorun
    sourceId = @selectedSourceId.get()
    @reviewed.set Articles.findOne(sourceId)?.reviewed or false

  @autorun =>
    @incidentsLoaded.set(false)
    @subscribe 'articleIncidents', @selectedSourceId.get(), =>
      @incidentsLoaded.set(true)
      Meteor.defer =>
        @$('.curator-source-details--content [data-toggle=tooltip]').tooltip
          delay: show: '300'
          container: 'body'

  @autorun =>
    source = Articles.findOne(@selectedSourceId.get())
    if source
      title = source.title
      # Update the document title and its tooltip in the right pane
      Meteor.defer =>
        $title = $('#sourceDetailsTitle')
        titleEl = $title[0]
        # Remove title and tooltip if the title is complete & without ellipsis
        if titleEl?.offsetWidth >= titleEl?.scrollWidth
          $title.tooltip('hide').attr('data-original-title', '')
        else
          $title.attr('data-original-title', title)
      enhancements = source.enhancements
      if enhancements?.dateOfDiagnosis or enhancements?.error or enhancements?.processingStartedAt
        return
      else
        Meteor.call 'getArticleEnhancementsAndUpdate', source._id

Template.curatorSourceDetails.onDestroyed ->
  $(window).off('resize')

Template.curatorSourceDetails.helpers
  isUsersDocument: ->
    @addedByUserId == Meteor.userId()

  incidents: ->
    Incidents.find()

  source: ->
    Articles.findOne(Template.instance().selectedSourceId.get())

  formattedScrapeDate: ->
    moment(Template.instance().data.sourceDate).format('MMMM DD, YYYY')

  formattedPromedDate: ->
    moment(Template.instance().data.promedDate).format('MMMM DD, YYYY')

  isReviewed: ->
    Template.instance().reviewed.get()

  notifying: ->
    Template.instance().notifying.get()

  selectedSourceId: ->
    Template.instance().selectedSourceId

  incidentsLoaded: ->
    Template.instance().incidentsLoaded.get()

  addingSourceToEvent: ->
    Template.instance().addingSourceToEvent.get()

  relatedElements: ->
    instance = Template.instance()
    parent: '.curator-source-details--copy-wrapper'
    sibling: '.curator-source-details--copy'
    sourceContainer: '.curator-source-details--copy'

  selectedAnnotationId: ->
    Template.instance().selectedAnnotationId

  textContent: ->
    source = Articles.findOne(Template.instance().selectedSourceId.get())
    source?.enhancements?.source?.cleanContent?.content

  selectedIncidents: ->
    Template.instance().selectedIncidents

  articleEvents: ->
    source = Articles.findOne(Template.instance().selectedSourceId.get())
    UserEvents.find(_id: $in: source.userEventIds)

Template.curatorSourceDetails.events
  'click .delete-document': (event, instance) ->
    Modal.show 'confirmationModal',
      html: Spacebars.SafeString(Blaze.toHTMLWithData(
        Template.deleteConfirmationModalBody,
        objNameToDelete: 'document'
        displayName: @title
      ))
      onConfirm: =>
        Meteor.call 'removeDocument', @_id, (error) ->
          instance.$(event.currentTarget).tooltip('destroy')

  'click .toggle-reviewed': (event, instance) ->
    instance.markReviewed()
    event.currentTarget.blur()

  'click .add-source-to-event': (event, instance) ->
    addingSourceToEvent = instance.addingSourceToEvent
    addingSourceToEvent.set(not addingSourceToEvent.get())
    event.currentTarget.blur()

  'click .back-to-list': (event, instance) ->
    instanceData = instance.data
    instanceData.currentPaneInView.set('')
    # Clear selected after animation so details UI does not dissapear
    setTimeout ->
      instanceData.selectedSourceId.set('')
    , 300

  'click .tabs a': (event, instance) ->
    instance.selectedIncidentTab.set(instance.$(event.currentTarget).data('tab'))

  'click .retry': (event, instance)->
    source = Articles.findOne(instance.selectedSourceId.get())
    Meteor.call 'getArticleEnhancementsAndUpdate', source._id, (error, enhancements) =>
      if error
        notify('error', error.reason)

  'click .disassociate-event': (event, instance)->
    event.stopPropagation()
    instanceData = instance.data
    Meteor.call 'removeEventSource', instance.selectedSourceId.get(), @_id, (error, res) ->
      $('.tooltip').remove()

  'click .add-incident': (event, instance) ->
    Modal.show 'incidentModal',
      incident:
        articleId: instance.selectedSourceId.get()
      add: true
      accept: true

  'click .reprocess': (event, instance) ->
    Meteor.call(
      'getArticleEnhancementsAndUpdate',
      instance.selectedSourceId.get(),
      reprocess: true
    )
