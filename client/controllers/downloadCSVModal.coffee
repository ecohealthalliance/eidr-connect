Template.downloadCSVModal.onCreated ->
  @tableExport = new ReactiveVar(true)

Template.downloadCSVModal.onRendered ->
  @data.rendered()

Template.downloadCSVModal.helpers
  getField: (row, field)->
    row[field]

  preparing: ->
    not Template.instance().tableExport.get()

Template.downloadCSVModal.events
  'click .download-csv': (event, instance) ->
    instance.tableExport.set(null)
    fileType = $(event.currentTarget).attr('data-type')
    table = instance.$('table')
    if table.length
      # Delay export so UI can respond to change in reactiveVars
      setTimeout ->
        instance.tableExport.set(table.tableExport(type: fileType).length)
      , 100
