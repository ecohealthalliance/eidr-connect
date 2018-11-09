import EventIncidents from '/imports/collections/eventIncidents'
import regionToCountries from '/imports/regionToCountries.json'
{
  removeOutlierIncidents
} = require('incident-resolution')

formatDateForInput = (date) ->
  unless date
    return moment()
  if date.getTime then date else new moment(date)

# Build query based on the state of the button/prop
propStates = (props) ->
  query = {}
  [ negative, positive ] = [false, true].map (state) ->
    _.filter(props, (prop) -> prop.state == state)
      .map((prop) -> prop.name)
  if positive.length
    query.$in = positive
  if negative.length
    query.$nin = negative
  query

inputState = (input) ->
  if 'negative' in input.classList then false else true

Template.eventFiltration.onCreated ->
  @PROP_PREFIX = 'filter-'
  @typeProps = ['cases', 'deaths']
  @statusProps = ['suspected', 'confirmed', 'revoked']
  @locationLevels = [
    {
      prop: 'region'
      name: 'Region'
    }
    {
      prop: 'countryName'
      name: 'Country'
    }
    {
      prop: 'admin1Name'
      name: 'First-order Admin Division'
    }
    {
      prop: 'admin2Name'
      name: 'Second-order Admin Division'
    }
  ]
  @types = new ReactiveVar([])
  @status = new ReactiveVar([])
  @properties = new ReactiveVar([
    name: 'outlier'
    state: false
  ])
  @countryLevel = new ReactiveVar(@locationLevels[0].prop)
  @selectedLocations = new Meteor.Collection(null)
  @locations = new Meteor.Collection(null)
  @speciesList = new Meteor.Collection(null)
  @selectedSpecies = new Meteor.Collection(null)
  @dateRange = new ReactiveVar([])
  @selectedDateRange = new ReactiveVar([])
  @eventDateRange = new ReactiveVar([ 0, 100 ])

  @removePropPrefix = (prop) =>
    prop.substr(@PROP_PREFIX.length)

  @insertLocation = (location) =>
    @selectedLocations.upsert _id: location._id,
      region: location.region
      countryName: location.countryName
      admin1Name: location.admin1Name
      admin2Name: location.admin2Name

  @setSelectedProps = (propWithState, inputClassName, propName) =>
    event.preventDefault()
    event.stopPropagation()
    selected = []
    Meteor.defer =>
      @$(".#{inputClassName} input:checked").each (i, input) =>
        name = @removePropPrefix(input.id)
        if propWithState
          prop =
            name: name
            state: inputState(input)
        else
          prop = name
        selected.push(prop)

      @[propName].set(selected)

Template.eventFiltration.onRendered ->
  # Update daterangepicker when slider and incidents collection changes
  @autorun =>
    defaultRange = @eventDateRange.get()
    selectedRange = @selectedDateRange.get()
    $pickerEl = @$('.daterange-input')
    $pickerEl.data('daterangepicker')?.remove()
    $pickerEl.daterangepicker
      minDate: defaultRange[0]
      maxDate: defaultRange[1]
      startDate: formatDateForInput(selectedRange[0])
      endDate: formatDateForInput(selectedRange[1])
      buttonClasses: 'btn'

  # Establish and update date ranges when incidents collection changes
  @autorun =>
    incidents = EventIncidents.find({}, fields: 'dateRange': 1).fetch()
    if incidents.length > 1
      range = [
        _.min(incidents.map (i) -> i.dateRange.start)
        _.max(incidents.map (i) -> i.dateRange.end)
      ]
      @eventDateRange.set(range)
      @selectedDateRange.set([
        # Limit default date range length to 1 month
        new Date(Math.max(range[0], moment(range[1]).subtract(1, 'month').toDate()))
        range[1]
      ])
    else
      # Set range as Numbers so range slider will not error out and will appear
      @eventDateRange.set([1, 100])

  @autorun =>
    @selectedSpecies.remove({})
    @speciesList.remove({})
    EventIncidents.find().map (incident) =>
      if incident.species?.id
        @speciesList.upsert(incident.species?.id,
          label: incident.species.text
        )
    @speciesList.insert(
      _id: "unspecified"
      label: "Unspecified"
    )

  # Establish and update locations when incidents collection changes
  @autorun =>
    incidentLocations = _.flatten(
      EventIncidents.find({}, field: locations: 1)
        .map (incident) ->
          incident.locations
    )
    countryLevel = @countryLevel.get()
    @locations.remove({})
    @selectedLocations.remove({})
    countryToRegion = {}
    for regionId, regionData of regionToCountries
      if regionData.continentCode
        regionData.countryISOs.forEach (iso) ->
          countryToRegion[iso] = regionData
    incidentLocations.forEach (location) =>
      return unless location.countryCode
      location.region = countryToRegion[location.countryCode].name
      return unless location[countryLevel]
      query = {}
      query[countryLevel] = location[countryLevel]
      @locations.upsert query,
        region: location.region
        countryName: location.countryName
        admin1Name: location.admin1Name
        admin2Name: location.admin2Name

  # Update filter query
  @autorun =>
    filters = {}

    # Daterange
    selectedRange = @selectedDateRange.get()
    defaultRange = @eventDateRange.get()
    startDate = new Date(selectedRange[0])
    endDate = new Date(selectedRange[1])
    isDefault = moment(defaultRange[0]).isSame(startDate) and
      moment(defaultRange[1]).isSame(endDate)
    if not isDefault and EventIncidents.find().count() > 1
      filters['dateRange.start'] =
        $lte: endDate
      filters['dateRange.end'] =
        $gte: startDate

    # Types
    types = @types.get()
    if types.length
      @data.selectedIncidentTypes.set(types)
      filters.$and = [
        $or:
          types.map (type) ->
            query = {}
            query[type] = $exists: true
            query
      ]
    else
      @data.selectedIncidentTypes.set(@typeProps)

    # Status
    status = @status.get()
    if status.length
      filters.status = {}
      filters.status = propStates(status)

    countryLevel = @countryLevel.get()
    selectedLocations = @selectedLocations.find().map (location) ->
      query = {}
      if countryLevel == 'region'
        regionInfo = _.findWhere(regionToCountries, name: location.region)
        query["locations.countryCode"] = $in: regionInfo.countryISOs
        return query
      for level in ['countryName', 'admin1Name', 'admin2Name']
        query["locations.#{level}"] = location[level]
        if countryLevel == level
          break
      query
    if selectedLocations.length
      filters.$and = (filters.$and or []).concat($or: selectedLocations)

    # Species
    selectedSpeciesIds = @selectedSpecies.find().map (x) ->
      if x._id != "unspecified" then x._id else null
    if selectedSpeciesIds.length > 0
      filters['species.id'] = $in: selectedSpeciesIds

    # Other Properties
    otherProps = @properties.get()
    travelRelated = _.findWhere(otherProps, name: "travelRelated")
    if travelRelated
      filters.travelRelated = travelRelated.state

    structured = _.findWhere(otherProps, name: "structured")
    if structured
      filters.sourceFeed =
        $exists: structured.state

    outliers = _.findWhere(otherProps, name: "outlier")
    if outliers
      baseIncidents = []
      constrainingIncidents = []
      EventIncidents.find(filters).map (incident) ->
        if incident.constraining
          constrainingIncidents.push incident
        else
          baseIncidents.push incident
      incidentsWithoutOutliers = removeOutlierIncidents(baseIncidents, constrainingIncidents)
      inlierIds = _.pluck(incidentsWithoutOutliers, '_id').concat(_.pluck(constrainingIncidents, '_id'))
      if outliers.state
        filters._id =
          $nin: inlierIds
      else
        filters._id =
          $in: inlierIds
    # Set filterQuery used to filter EventIncidents collection
    # in child templates.
    @data.filterQuery.set(filters)

Template.eventFiltration.helpers
  typeProps: ->
    Template.instance().typeProps

  statusProps: ->
    Template.instance().statusProps

  propPrex: ->
    Template.instance().PROP_PREFIX

  locationLevels: ->
    Template.instance().locationLevels

  locations: ->
    Template.instance().locations.find()

  locationName: ->
    @[Template.instance().countryLevel.get()]

  locationSelected: ->
    Template.instance().selectedLocations.findOne(@_id)

  noLocationsSelected: ->
    Template.instance().selectedLocations.find().count() == 0

  sliderData: ->
    instance = Template.instance()
    sliderRange: instance.eventDateRange
    selectedRange: instance.selectedDateRange

  hasDateRange: ->
    range = Template.instance().eventDateRange.get()
    return false if _.isNumber(range?[0])
    range?[0].valueOf() < range?[1].valueOf()

  filtering: ->
    not _.isEmpty(Template.instance().data.filterQuery.get())

  speciesList: ->
    Template.instance().speciesList.find()

  speciesSelected: ->
    Template.instance().selectedSpecies.findOne(@_id)

  noSpeciesSelected: ->
    Template.instance().selectedSpecies.find().count() == 0

Template.eventFiltration.events
  'change .type input': (event, instance) ->
    instance.setSelectedProps(false, 'type', 'types', event)

  'click .status input': (event, instance) ->
    instance.setSelectedProps(true, 'status', 'status', event)

  'click .other-properties input': (event, instance) ->
    instance.setSelectedProps(true, 'other-properties', 'properties', event)

  'change .locations select': (event, instance) ->
    instance.countryLevel.set(event.target.value)

  'click .location-list li': (event, instance) ->
    selectedLocations = instance.selectedLocations
    if selectedLocations.findOne(@_id)
      selectedLocations.remove(@_id)
    else
      instance.insertLocation(@)

  'click .locations .deselect-all': (event, instance) ->
    instance.selectedLocations.remove({})

  'click .species .deselect-all': (event, instance) ->
    instance.selectedSpecies.remove({})

  'click .species-list li': (event, instance) ->
    selectedSpecies = instance.selectedSpecies
    if selectedSpecies.findOne(@_id)
      selectedSpecies.remove(@_id)
    else
      selectedSpecies.insert(@)

  'apply.daterangepicker': (event, instance, picker) ->
    instance.selectedDateRange.set([picker.startDate, picker.endDate])

  'show.daterangepicker': (event, instance, picker) ->
    # Add custom class to picker for custom styling
    $('.daterangepicker').addClass('event--filtration-picker')

  'click .clear-filters': (event, instance) ->
    instance.$('.check-buttons input:checked')
      .attr('checked', false)
      .removeClass()
    instance.types.set([])
    instance.data.selectedIncidentTypes.set([])
    instance.status.set([])
    instance.properties.set([])
    instance.selectedLocations.remove({})
    instance.selectedDateRange.set(instance.eventDateRange.get())
