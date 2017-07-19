Template.eventFiltration.onCreated ->
  @types = new ReactiveVar([])
  @autorun =>
    filters = {}
    types = @types.get()
    types.forEach (type) ->
      filters[type.prop] = type.query
    @data.filterQuery.set(filters)

Template.eventFiltration.helpers
  types: ->
    Template.instance().types.get()


Template.eventFiltration.events
  'change .type input': (event, instance) ->
    types = []
    instance.$('.type input').each (i, input) ->
      if not input.checked
        types.push
          prop: input.id
          query: $exists: input.checked
    instance.types.set(types)
