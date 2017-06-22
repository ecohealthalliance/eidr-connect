import { formatLocation } from '/imports/utils'
import Incidents from '/imports/collections/incidentReports.coffee'
import Constants from '/imports/constants.coffee'
import GeonameSchema from '/imports/schemas/geoname.coffee'
import { stageModals } from '/imports/ui/modals'

incidentsToLocations = (incidents) ->
  locations = {}
  # Loop 1: Incidents
  for incident in incidents
    if incident?.locations
      # Loop 2: Locations within each incident record
      for loc in incident.locations
        if !locations[loc.id]
          locations[loc.id] = loc
  # Return
  _.values(locations)

Template.locationSelect2.onCreated ->
  @values = @data.values or new ReactiveVar([])
  @required = @data.required
  @required ?= false
  # Display locations relevant to this event
  @suggestLocations = (term, callback) ->
    locations = incidentsToLocations Incidents.find().fetch()
    data = []
    for loc in locations
      data.push { id: loc.id, text: formatLocation(loc), item: loc }
    callback results: data
  # Retrieve locations from a server
  @ajax = (term, callback) ->
    $.ajax
      url: Constants.GRITS_URL + "/api/geoname_lookup/api/lookup"
      data:
        q: term
        maxRows: 10
    .done (data) ->
      callback results: data.hits.map (hit) ->
        { id, latitude, longitude } = hit._source
        # Ensure numeric lat/lng
        hit._source.latitude = parseFloat(latitude)
        hit._source.longitude = parseFloat(longitude)
        id: id
        text: formatLocation(hit._source)
        item: GeonameSchema.clean(hit._source)

Template.locationSelect2.onRendered ->
  initialValues = []
  required = @data.required
  if @data.selected
    initialValues = @data.selected.map (loc)->
      id: loc.id
      text: formatLocation(loc)
      item: loc
  @values.set(initialValues)
  $.fn.select2.amd.define 'select2/data/queryAdapter',
    [ 'select2/data/array', 'select2/utils' ],
    (ArrayAdapter, Utils) =>
      CustomDataAdapter = ($element, options) ->
        CustomDataAdapter.__super__.constructor.call(@, $element, options)
      Utils.Extend(CustomDataAdapter, ArrayAdapter)
      CustomDataAdapter.prototype.query = _.debounce (params, callback) =>
        term = params.term?.trim()
        if term # Query the remote server for any matching locations
          @ajax(term, callback)
        else # Show recently used locations for the current event
          @suggestLocations(term, callback)
      , 600
      CustomDataAdapter

  @autorun =>
    values = @values.get()
    $input = @$("select")
    if $input.data('select2')
      $input.select2('close')
      $input.select2('destroy')
    queryDataAdapter = $.fn.select2.amd.require('select2/data/queryAdapter')
    $input.select2
      data: values
      multiple: @data.multiple
      placeholder: 'Search for a location...'
      minimumInputLength: 0
      dataAdapter: queryDataAdapter

    if required
      if values.length > 0
        required = false
      @$('.select2-search__field').attr
        'required': required
        'data-error': 'Please select a location.'

    $input.val(values.map((x)->x.id)).trigger('change')

Template.locationSelect2.events
  'change select': _.debounce((event, instance) ->
    selectedValues = instance.$("select").select2('data')
    uniqueValues = _.uniq(_.pluck(instance.values.get(), 'id'))
    uniqueSelectedValues = _.uniq(_.pluck(selectedValues, 'id'))
    intersection = _.intersection(uniqueValues, uniqueSelectedValues)
    if intersection.length != uniqueSelectedValues.length or uniqueValues.length != uniqueSelectedValues.length
      instance.values.set(selectedValues.map (data)->
        id: data.id
        text: data.text
        item: data.item
      )
  , 300)
  'select2:open': (event, instance) ->
    if instance.data.allowAdd
      unless $('.select2-results__additional-options').length
        $('.select2-dropdown').addClass('select2-dropdown--with-additional-options')
        Blaze.renderWithData Template.addLocationControl,
          onClick: ->
            stageModals instance,
              currentModal:
                element: '#suggestedIncidentModal'
                remove: 'off-canvas--top'
                add: 'staged-left'
            instance.$('select').select2('close')
            Modal.show 'addGeonameModal',
              onAdded: (value)->
                instance.values.set instance.values.get().concat
                  id: value.id
                  text: value.name
                  item: value
        , document.querySelector('.select2-results')

Template.addLocationControl.events
  'click button': (event, instance) ->
    instance.data.onClick()
