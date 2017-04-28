Template.downloadCSVModal.helpers
  getField: (row, field)->
    row[field]

Template.downloadCSVModal.events
  'click .download-csv': (event, instance) ->
    fileType = $(event.currentTarget).attr('data-type')
    table = instance.$('table')
    if table.length
      table.tableExport(type: fileType)
