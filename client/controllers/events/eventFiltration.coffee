import EventIncidents from '/imports/collections/eventIncidents'

formatDateForInput = (date) ->
  date = if date.getTime then date else new Date(Math.ceil(date))
  moment(date).format('YYYY-MM-DD')

Template.eventFiltration.onCreated ->
  @PROP_PREFIX = 'filter-'
  @typeProps = ['cases', 'deaths']
  @statusProps = ['suspected', 'confirmed', 'revoked']
  @locationLevels = [
    {
      prop: 'countryName'
      name: 'Country Name'
    }
    {
      prop: 'admin1Name'
      name: 'Admin Name 1'
    }
    {
      prop: 'admin2Name'
      name: 'Admin Name 2'
    }
  ]
  @types = new ReactiveVar([])
  @status = new ReactiveVar([])
  @properties = new ReactiveVar({})
  @countryLevel = new ReactiveVar('countryName')
  @selectedLocations = new Meteor.Collection(null)
  @locations = new Meteor.Collection(null)
  @dateRange = new ReactiveVar([])
  @autorun =>
    incidents = EventIncidents.find({}, fields: 'dateRange': 1).fetch()
    @eventDateRange = [
      _.min(incidents.map (i) -> i.dateRange.start)
      _.max(incidents.map (i) -> i.dateRange.end)
    ]
    @dateRange.set(@eventDateRange)

  @autorun =>
    filters = {}

    # Daterange
    dateRange = @dateRange.get()
    if dateRange.length
      filters['dateRange.start'] =
        $lte: new Date(Math.ceil(dateRange[1]))
      filters['dateRange.end'] =
        $gte: new Date(Math.ceil(dateRange[0]))

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

  @removePropPrefix = (prop) =>
    prop.substr(@PROP_PREFIX.length)

  @insertLocation = (location) =>
    @selectedLocations.upsert _id: location._id,
      countryName: location.countryName
      admin1Name: location.admin1Name
      admin2Name: location.admin2Name

Template.eventFiltration.onRendered ->
  @autorun =>
    @incidentLocations = _.uniq(
      _.flatten(EventIncidents.find({}, field: locations: 1).map (incident) ->
        incident.locations
      )
    )

  @autorun =>
    countryLevel = @countryLevel.get()
    @locations.remove({})
    @selectedLocations.remove({})
    @incidentLocations.forEach (location) =>
      return unless location[countryLevel]
      query = {}
      query[countryLevel] = location[countryLevel]
      @locations.upsert query,
        countryName: location.countryName
        admin1Name: location.admin1Name
        admin2Name: location.admin2Name

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
    eventDateRange = instance.eventDateRange
    min = eventDateRange[0]
    max = eventDateRange[1]
    # If min and max dates are equal change to 0,100 so slider renders
    # it will be disabled in UI
    if min.getTime() == max.getTime()
      min = 0
      max = 100
    sliderMin: min
    sliderMax: max
    range: instance.dateRange

  startDate: ->
    formatDateForInput(Template.instance().dateRange.get()[0])

  endDate: ->
    formatDateForInput(Template.instance().dateRange.get()[1])

  minDate: ->
    formatDateForInput(Template.instance().eventDateRange[0])

  maxDate: ->
    formatDateForInput(Template.instance().eventDateRange[1])

  hasDateRange: ->
    range = Template.instance().dateRange.get()
    range[0] < range[1]

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
    selectedLocations.find().fetch()

  'click .locations .select-all': (event, instance) ->
    instance.locations.find().forEach (location) ->
      instance.insertLocation(location)

  'click .locations .deselect-all': (event, instance) ->
    instance.selectedLocations.remove({})

  'change .dates input': (event, instance) ->
    dates = []
    instance.$('.dates input').each (i, input) ->
      dates.push(new Date(input.value))
    instance.dateRange.set(dates)
