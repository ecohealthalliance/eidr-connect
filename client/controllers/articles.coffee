Incidents = require '/imports/collections/incidentReports.coffee'
EventArticles = require '/imports/collections/eventArticles.coffee'
{ keyboardSelect } = require '/imports/utils'

Template.articles.onCreated ->
  @selectedSourceId = new ReactiveVar(null)
  @incidentsLoaded = new ReactiveVar(false)

Template.articles.onRendered ->
  instance = @
  @autorun =>
    sourceId = @selectedSourceId.get()
    if sourceId
      @incidentsLoaded.set(false)
      @subscribe 'articleIncidents', sourceId, =>
        @incidentsLoaded.set(true)
        Meteor.defer =>
          @$('[data-toggle=tooltip]').tooltip delay: show: '300'

Template.articles.helpers
  getSettings: ->
    fields = [
      {
        key: 'title'
        label: 'Title'
        fn: (value, object, key) ->
          object.title or object.url or (object.content?.slice(0,30) + "...")
      },
      {
        key: 'addedDate'
        label: 'Added'
        fn: (value, object, key) ->
          return moment(value).fromNow()
        sortFn: (value) ->
          value
      },
      {
        key: 'publishDate'
        label: 'Publication Date'
        fn: (value, object, key) ->
          if value
            return moment(value).format('MMM D, YYYY')
          return ''
        sortFn: (value) ->
          value
      }
    ]

    fields.push
      key: 'expand'
      label: ''
      cellClass: 'action open-right'

    id: 'event-sources-table'
    fields: fields
    showFilter: false
    showNavigationRowsPerPage: false
    showRowCount: false
    class: 'table event-sources'
    filters: ['sourceFilter']

  selectedSource: ->
    EventArticles.findOne(Template.instance().selectedSourceId.get())

  selectedSourceTitle: ->
    source = EventArticles.findOne(Template.instance().selectedSourceId.get())
    source.title or source.url or (source.content?.slice(0,30) + "...")

  incidentsForSource: (source) ->
    Incidents.find(articleId: Template.instance().selectedSourceId.get())

  locationsForSource: (source) ->
    locations = {}
    Incidents
      .find
        articleId: source._id
      .forEach (incident) ->
        for location in incident.locations
          locations[location.id] = location.name
    _.flatten locations

  searchSettings: ->
    id: 'sourceFilter'
    placeholder: 'Search documents'
    toggleable: false
    props: ['title']

  incidentsLoaded: ->
    Template.instance().incidentsLoaded.get()

  incidentAssociatedWithEvent: ->
    eventIncidentIds = _.pluck(Template.instance().data.userEvent.incidents, 'id')
    @_id in eventIncidentIds

  eventHasArticleIncidents: ->
    eventIncidentIds = _.pluck(Template.instance().data.userEvent.incidents, 'id')
    Incidents.find(_id: $in: eventIncidentIds).count()

Template.articles.events
  'click #event-sources-table tbody tr
    , keyup #event-sources-table tbody tr': (event, instance) ->
    event.preventDefault()
    return if not keyboardSelect(event) and event.type is 'keyup'
    instance.selectedSourceId.set(@_id)
    instance.$(event.currentTarget).parent().find('tr').removeClass 'open'
    instance.$(event.currentTarget).addClass('open').blur()
    instance.$('.event-sources-detail').focus()

  'click .open-source-form': (event, instance) ->
    Modal.show 'sourceModal', userEventId: instance.data.userEvent._id

  'click .delete-source:not(.disabled)': (event, instance) ->
    sourceId = instance.selectedSourceId.get()
    Modal.show 'confirmationModal',
      html: Spacebars.SafeString(Blaze.toHTMLWithData(
        Template.deleteConfirmationModalBody,
        objNameToDelete: 'Document'
      ))
      onConfirm: ->
        Meteor.call 'removeEventSource', sourceId, instance.data.userEvent._id, (error) ->
          instance.$(event.currentTarget).tooltip('destroy')

  'click .edit-source': (event, instance) ->
    Modal.show 'sourceModal',
      source: EventArticles.findOne(instance.selectedSourceId.get())
    instance.$(event.currentTarget).tooltip('destroy')

  'click .show-document-text-modal': (event, instance) ->
    article = EventArticles.findOne(instance.selectedSourceId.get())
    Modal.show 'documentTextModal',
      title: article.title or (article.content?.slice(0,30) + "...")
      text: article.content

Template.articleSelect2.onRendered ->
  $input = @$('select')
  options = {}
  if @data.multiple
    options.multiple = true
  options.placeholder = @data.placeholder or ''
  $input.select2(options)

  if @data.selected
    $input.val(@data.selected).trigger('change')
  $input.next('.select2-container').css('width', '100%')

Template.articleSelect2.onDestroyed ->
  selectId = @data.selectId
  if selectId
    Meteor.defer ->
      @$("##{selectId}").select2('destroy')
