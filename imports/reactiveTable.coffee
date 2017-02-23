module.exports =
  manageTableSorting: (instance) ->
    tableOptions = instance.tableOptions
    fields = tableOptions.fields
    tableName = tableOptions.name
    for field in fields
      fieldName = field.fieldName
      visibility = Session.get("#{tableName}-field-visible-#{fieldName}") or true
      tableOptions.fieldVisibility[fieldName] = new ReactiveVar(visibility)

      sortOrder = Session.get("#{tableName}-field-sort-order-#{fieldName}") or Infinity
      tableOptions.sortOrder[fieldName] = new ReactiveVar(sortOrder)

      sortDirection = Session.get("#{tableName}-field-sort-direction-#{fieldName}") or field.defaultSortDirection
      tableOptions.sortDirection[fieldName] = new ReactiveVar(sortDirection)

    instance.autorun ->
      Session.set "#{tableName}-current-page", instance.currentPage.get()
      Session.set "#{tableName}-rows-per-page", instance.rowsPerPage.get()
      for field in tableOptions.fields
        fieldName = field.fieldName
        Session.set "#{tableName}-field-visible-#{fieldName}", tableOptions.fieldVisibility[fieldName].get()
        Session.set "#{tableName}-field-sort-order-#{fieldName}", tableOptions.sortOrder[fieldName].get()
        Session.set "#{tableName}-field-sort-direction-#{fieldName}", tableOptions.sortDirection[fieldName].get()

  tableFields: (instance) ->
    tableOptions = instance.tableOptions
    fields = []
    for field in tableOptions.fields
      fieldName = field.fieldName
      tableField =
        key: fieldName
        label: field.displayName
        isVisible: tableOptions.fieldVisibility[fieldName]
        sortOrder: tableOptions.sortOrder[fieldName]
        sortDirection: tableOptions.sortDirection[fieldName]
        sortable: not field.arrayName

      if field.displayFn
        tableField.fn = field.displayFn
      fields.push(tableField)
    fields

  gotoEvent: (event, instance) ->
    route = instance.tableOptions.name.slice(0, -1)
    if event.metaKey
      url = Router.url route, _id: @_id
      window.open(url, '_blank')
    else
      Router.go route, _id: @_id

  scrollToTop: ->
    if window.scrollY > 0 and window.innerHeight < 700
      $(document.body).animate({scrollTop: 0}, 400)
