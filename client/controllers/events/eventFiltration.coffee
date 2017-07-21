Template.eventFiltration.onCreated ->
  @PROP_PREFIX = 'filter-'
  @typeProps = ['cases', 'deaths']
  @statusProps = ['suspected', 'confirmed', 'revoked']
  @types = new ReactiveVar([])
  @status = new ReactiveVar([])
  @properties = new ReactiveVar({})
  @autorun =>
    filters = {}
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

    status = @status.get()
    if status.length
      filters.status =
        $in: status

    filters = _.extend(filters, @properties.get())

    # Set filterQuery used to filter EventIncidents collection
    # in child templates.
    @data.filterQuery.set(filters)

  @removePropPrefix = (prop) =>
    prop.substr(@PROP_PREFIX.length)

Template.eventFiltration.helpers
  typeProps: ->
    Template.instance().typeProps

  statusProps: ->
    Template.instance().statusProps

  propPrex: ->
    Template.instance().PROP_PREFIX

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
