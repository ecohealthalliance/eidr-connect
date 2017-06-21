Template.downloadCSVModal.onCreated ->
  @prepared = new ReactiveVar(null)
  @preparing = new ReactiveVar(false)

  @autorun =>
    if @prepared.get()
      @preparing.set(false)

Template.downloadCSVModal.onRendered ->
  @data.rendered()

Template.downloadCSVModal.helpers
  getField: (row, field)->
    row[field]

  preparing: ->
    Template.instance().preparing.get()

Template.downloadCSVModal.events
  'click .download-csv': (event, instance) ->
    instance.prepared.set(null)
    instance.preparing.set(true)
    fileType = $(event.currentTarget).attr('data-type')
    table = instance.$('table')
    if table.length
      # Delay export so UI can respond to change in reactiveVars
      setTimeout ->
        instance.prepared.set(table.tableExport(type: fileType).length)
      , 100
