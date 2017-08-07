import EventIncidents from '/imports/collections/eventIncidents'
import regionToCountries from '/imports/regionToCountries.json'

formatDateForInput = (date) ->
  unless date
    return moment.utc().format('MM/DD/YYYY')
  date = if date.getTime then date else new Date(Math.ceil(date))
  moment.utc(date).format('MM/DD/YYYY')

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
  @properties = new ReactiveVar({})
  @countryLevel = new ReactiveVar(@locationLevels[0].prop)
  @selectedLocations = new Meteor.Collection(null)
  @locations = new Meteor.Collection(null)
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

  @setPickerDates = (defaultRange, selectedDateRange) =>
    selectedDateRange ?= defaultRange
    ['start', 'end'].forEach (input, i) =>
      $input = @$(".#{input}-date").data("DateTimePicker")
      if $input
        $input.date(new Date(Math.ceil(selectedDateRange[i])))
        $input.minDate(defaultRange[0])
        $input.maxDate(defaultRange[1])

Template.eventFiltration.onRendered ->
  # Instatiate date pickers for start and end date
  Meteor.defer =>
    settings =
      format: 'MM/DD/YYYY'
    @$('.start-date').datetimepicker(settings)
    @$('.end-date').datetimepicker(settings)

  # Establish and update date ranges when incidents collection changes
  @autorun =>
    incidents = EventIncidents.find({}, fields: 'dateRange': 1).fetch()
    if incidents.length > 1
      range = [
        _.min(incidents.map (i) -> i.dateRange.start)
        _.max(incidents.map (i) -> i.dateRange.end)
      ]
      @eventDateRange.set(range)
      @selectedDateRange.set(range)
      @setPickerDates(range)
    else
      # Set range as Numbers so range slider will not error out and will appear
      @eventDateRange.set([1, 100])

  # Establish and update locations when incidents collection changes
  @autorun =>
    incidentLocations = _.uniq(
      _.flatten(EventIncidents.find({}, field: locations: 1).map (incident) ->
        incident.locations
      )
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
    selectedDateRange = @selectedDateRange.get()
    eventDateRange = @eventDateRange.get()
    @setPickerDates(eventDateRange, selectedDateRange)
    isDefaultRange = selectedDateRange[0] == eventDateRange[0] and
      selectedDateRange[1] == eventDateRange[1]
    if selectedDateRange.length and not isDefaultRange
      startDate = new Date(Math.ceil(selectedDateRange[1]))
      endDate = new Date(Math.ceil(selectedDateRange[0]))
      filters['dateRange.start'] =
        $lte: startDate
      filters['dateRange.end'] =
        $gte: endDate

    # Types
    types = @types.get()
    if types.length
      @data.selectedIncidentTypes.set(types)
      filters.$or =
        types.map (type) ->
          query = {}
          query[type] = $exists: true
          query
    else
      @data.selectedIncidentTypes.set(@typeProps)

    # Status
    status = @status.get()
    if status.length
      filters.status =
        $in: status

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
      filters.$or = (filters.$or or []).concat selectedLocations

    # Other Properties
    filters = _.extend(filters, @properties.get())

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

  allLocationsSelected: ->
    instance = Template.instance()
    instance.selectedLocations.find().count() == instance.locations.find().count()

  noEventsSelected: ->
    Template.instance().selectedLocations.find().count() == 0

  sliderData: ->
    instance = Template.instance()
    sliderRange: instance.eventDateRange
    selectedRange: instance.selectedDateRange

  startDate: ->
    formatDateForInput(Template.instance().selectedDateRange.get()?[0])

  endDate: ->
    formatDateForInput(Template.instance().selectedDateRange.get()?[1])

  hasDateRange: ->
    range = Template.instance().eventDateRange.get()
    return false if _.isNumber(range?[0])
    range?[0].valueOf() < range?[1].valueOf()

  filtering: ->
    not _.isEmpty(Template.instance().data.filterQuery.get())

Template.eventFiltration.events
  'change .type input': (event, instance) ->
    types = []
    instance.$('.type input:checked').each (i, input) ->
      types.push instance.removePropPrefix(input.id)
    instance.types.set(types)

  'change .status input': (event, instance) ->
    status = []
    instance.$('.status input:checked').each (i, input) ->
      status.push instance.removePropPrefix(input.id)
    instance.status.set(status)

  'change .other-properties input': (event, instance) ->
    otherProps = {}
    instance.$('.other-properties input:checked').each (i, input) ->
      otherProps[instance.removePropPrefix(input.id)] = true
    instance.properties.set(otherProps)

  'change .locations select': (event, instance) ->
    instance.countryLevel.set(event.target.value)

  'click .location-list li': (event, instance) ->
    selectedLocations = instance.selectedLocations
    if selectedLocations.findOne(@_id)
      selectedLocations.remove(@_id)
    else
      instance.insertLocation(@)

  'click .locations .select-all': (event, instance) ->
    instance.locations.find().forEach (location) ->
      instance.insertLocation(location)

  'click .locations .deselect-all': (event, instance) ->
    instance.selectedLocations.remove({})

  'dp.change': (event, instance) ->
    dates = []
    instance.$('.dates input').each (i, input) ->
      dates.push(new Date(input.value))
    if dates.length > 1
      instance.selectedDateRange.set(dates)

  'click .clear-filters': (event, instance) ->
    instance.$('.check-buttons input:checked').attr('checked', false)
    instance.types.set([])
    instance.data.selectedIncidentTypes.set([])
    instance.status.set([])
    instance.properties.set({})
    instance.selectedLocations.remove({})
    instance.selectedDateRange.set(instance.eventDateRange.get())
