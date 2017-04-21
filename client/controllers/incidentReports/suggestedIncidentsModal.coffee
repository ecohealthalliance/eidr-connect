incidentReportSchema = require('/imports/schemas/incidentReport.coffee')
UserEvents = require('/imports/collections/userEvents')
Incidents = require('/imports/collections/incidentReports')
Constants = require('/imports/constants.coffee')
{ notify } = require('/imports/ui/notification')
{ stageModals } = require('/imports/ui/modals')
import { annotateContentWithIncidents,
  buildAnnotatedIncidentSnippet } from '/imports/ui/annotation'
import { formatUrl, createIncidentReportsFromEnhancements } from '/imports/utils.coffee'

# determines if the user should be prompted before leaving the current modal
#
# @param {object} event, the DOM event
# @param {object} instance, the template instance
confirmAbandonChanges = (event, instance) ->
  collection = instance.collection()
  total = collection.find().count()
  count = collection.find(accepted: true).count()
  if count > 0 && instance.hasBeenWarned.get() == false
    event.preventDefault()
    Modal.show 'cancelConfirmationModal',
      modalsToCancel: ['suggestedIncidentsModal', 'cancelConfirmationModal']
      displayName: "Abandon #{count} of #{total} incidents accepted?"
      hasBeenWarned: instance.hasBeenWarned
    false
  else
    true

showSuggestedIncidentModal = (event, instance)->
  incident = instance
    .collection()
    .findOne($(event.currentTarget)
    .data("incident-id"))
  content = Template.instance().content.get()
  snippetHtml = buildAnnotatedIncidentSnippet(content, incident)

  Modal.show 'suggestedIncidentModal',
    articles: [instance.data.article]
    userEventId: instance.data.userEventId
    incidentCollection: Incidents
    incident: incident
    incidentText: Spacebars.SafeString(snippetHtml)

modalClasses = (modal, add, remove) ->
  modal.currentModal.add = add
  modal.currentModal.remove = remove
  modal

dismissModal = (instance) ->
  modal = modalClasses(instance.modal, 'off-canvas--top', 'staged-left')
  stageModals(instance, modal)

sendModalOffStage = (instance) ->
  startPosition = instance.data.offCanvasStartPosition
  startPosition ?= 'right'
  modal = modalClasses(instance.modal, 'staged-left', "off-canvas--#{startPosition} fade")
  stageModals(instance, modal, false)

Template.suggestedIncidentsModal.onCreated ->
  @hasBeenWarned = new ReactiveVar(false)
  @loading = new ReactiveVar(true)
  @content = new ReactiveVar('')
  @annotatedContentVisible = new ReactiveVar(true)
  @modal =
    currentModal:
      element: '#suggestedIncidentsModal'
  @saveResults = @data.saveResults
  @saveResults ?= true

  if @saveResults
    @autorun =>
      @subscribe 'ArticleIncidentReports', @data.article._id
  else
    @incidentsCollection = new Meteor.Collection(null)

  @collection = =>
    if @saveResults
      Incidents
    else
      @incidentsCollection

Template.suggestedIncidentsModal.onRendered ->
  $('#event-source').on 'hidden.bs.modal', ->
    $('body').addClass('modal-open')

  source = @data.article
  Meteor.call 'getArticleEnhancements', source, (error, enhancements) =>
    if error
      Modal.hide(@)
      toastr.error error.reason
      return
    source.enhancements = enhancements
    if @saveResults
      Meteor.call 'getArticleEnhancementsAndUpdate', source,  (error, enhancements) =>
        if error
          notify('error', error.reason)
        else
          source.enhancements = enhancements
          @loading.set(false)
          @content.set(enhancements.source.cleanContent.content)
    else
      incidents = createIncidentReportsFromEnhancements enhancements,
        acceptByDefault: true
      @loading.set(false)
      @content.set(enhancements.source.cleanContent.content)
      incidents.forEach (incident) =>
        @incidentsCollection.insert(incident)

Template.suggestedIncidentsModal.onDestroyed ->
  $('#suggestedIncidentsModal').off('hide.bs.modal')

Template.suggestedIncidentsModal.helpers
  showTable: ->
    instance = Template.instance()
    incidents = instance.collection().find
      accepted: true
      specify: $exists: false
    instance.data.showTable and incidents?.count()

  incidents: ->
    Template.instance().collection().find
      accepted: true
      specify: $exists: false

  incidentsFound: ->
    Template.instance().collection().find().count()

  isLoading: ->
    Template.instance().loading.get()

  annotatedContent: ->
    instance = Template.instance()
    incidents = instance.collection().find().fetch()
    annotateContentWithIncidents(instance.content.get(), incidents)

  annotatedCount: ->
    collection = Template.instance().collection()
    total = collection.find().count()
    if total
      count = collection.find(accepted: true).count()
      "#{count} of #{total} incidents accepted"

  annotatedContentVisible: ->
    Template.instance().annotatedContentVisible.get()

  tableVisible: ->
    not Template.instance().annotatedContentVisible.get()

  incidentProperties: ->
    properties = []
    if @travelRelated
      properties.push "Travel Related"
    if @dateRange?.cumulative
      properties.push "Cumulative"
    if @approximate
      properties.push "Approximate"
    properties.join(";")

  content: ->
    Template.instance().content.get()

  source: ->
    Template.instance().data.article

  relatedElements: ->
    parent: '.suggested-incidents .modal-content'
    sibling: '.suggested-incidents .modal-body'
    sourceContainer: '.suggested-incidents-wrapper'

  offCanvasStartPosition: ->
    Template.instance().data.offCanvasStartPosition or 'right'

  saveResults: ->
    Template.instance().saveResults

Template.suggestedIncidentsModal.events
  'hide.bs.modal #suggestedIncidentsModal': (event, instance) ->
    proceed = confirmAbandonChanges(event, instance)
    if proceed and $(event.currentTarget).hasClass('in')
      dismissModal(instance)
      event.preventDefault()

  'click .annotation': (event, instance) ->
    sendModalOffStage(instance)
    showSuggestedIncidentModal(event, instance)

  'click #add-suggestions': (event, instance) ->
    instance.$(event.currentTarget).blur()
    incidents = Incidents.find(
      accepted: true
    ).map (incident)->
      _.pick(incident, incidentReportSchema.objectKeys())
    count = incidents.length
    if count <= 0
      notify('warning', 'No incidents have been confirmed')
      return
    Meteor.call 'addIncidentReports', incidents, (err, result)->
      if err
        toastr.error err.reason
      else
        # we need to allow the modal to close without warning confirmAbandonChanges
        # since the incidents have been saved to the remote, it makes sense to
        # empty our collection temporary work.
        # hide the modal
        notify('success', 'Incident Added')
        dismissModal(instance)

  'click #non-suggested-incident': (event, instance) ->
    sendModalOffStage(instance)
    Modal.show 'incidentModal',
      articles: [instance.data.article]
      userEventId: instance.data.userEventId
      add: true
      incident:
        articleId: instance.data.article._id
      offCanvas: 'right'

  'click #save-csv': (event, instance) ->
    fileType = $(event.currentTarget).attr('data-type')
    table = instance.$('table.incident-table')
    if table.length
      table.tableExport(type: fileType)

  'click .incident-report': (event, instance) ->
    sendModalOffStage(instance)
    showSuggestedIncidentModal(event, instance)

  'click .annotated-content-tab': (event, instance) ->
    instance.annotatedContentVisible.set true

  'click .incident-table-tab': (event, instance) ->
    instance.annotatedContentVisible.set false
