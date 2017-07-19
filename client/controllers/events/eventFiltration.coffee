Template.eventFiltration.onCreated ->
  @typeProps = ['cases', 'deaths']
  @statusProps = ['suspected', 'confirmed', 'revoked']
  @types = new ReactiveVar([])
  @status = new ReactiveVar(@statusProps)
  @autorun =>
    filters = {}
    types = @types.get()
    types.forEach (type) ->
      filters[type.prop] = type.query
    filters.status =
      $in: @status.get()

    # Set filterQuery used to filter Event Incidents collection
    # in child templates.
    @data.filterQuery.set(filters)

Template.eventFiltration.helpers
  typeProps: ->
    Template.instance().typeProps

  statusProps: ->
    Template.instance().statusProps

Template.eventFiltration.events
  'change .type input': (event, instance) ->
    types = []
    instance.$('.type input').each (i, input) ->
      if not input.checked
        types.push
          prop: input.id
          query: $exists: input.checked
    instance.types.set(types)

  'change .status input': (event, instance) ->
    types = []
    instance.$('.status input:checked').each (i, input) ->
      types.push input.id
    instance.status.set(types)
