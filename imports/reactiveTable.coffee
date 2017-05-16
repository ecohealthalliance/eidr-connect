module.exports =
  ###
  # manageTableSorting - Updates Session variables related to sorting of each
  # table field
  #
  # @param {object} instance, instance of template containing table
  ###
  manageTableSorting: (instance) ->
    tableOptions = instance.tableOptions
    fields = tableOptions.fields
    tableName = tableOptions.name
    i = 0
    for fieldName, field of fields
      visibility = Session.get("#{tableName}-field-visible-#{fieldName}") or true
      tableOptions.fieldVisibility[fieldName] = new ReactiveVar(visibility)

      sortOrder = Session.get("#{tableName}-field-sort-order-#{fieldName}") or field.sortOrder or i
      tableOptions.sortOrder[fieldName] = new ReactiveVar(sortOrder)
      i++

      sortDirection = Session.get("#{tableName}-field-sort-direction-#{fieldName}") or field.defaultSortDirection
      tableOptions.sortDirection[fieldName] = new ReactiveVar(sortDirection)

    instance.autorun ->
      Session.set "#{tableName}-current-page", instance.currentPage.get()
      Session.set "#{tableName}-rows-per-page", instance.rowsPerPage.get()
      for fieldName in _.keys(fields)
        Session.set "#{tableName}-field-visible-#{fieldName}", tableOptions.fieldVisibility[fieldName].get()
        Session.set "#{tableName}-field-sort-order-#{fieldName}", tableOptions.sortOrder[fieldName].get()
        Session.set "#{tableName}-field-sort-direction-#{fieldName}", tableOptions.sortDirection[fieldName].get()

  ###
  # tableFields - creates the fields array to pass to the ReactiveTable within
  # settings. Field criterial is added to the fields array of the tableOptions object on
  # the template instance
  #
  # @param {object} instance, instance of template containing table
  # @return {array} fields, array containing fields for ReactiveTable
  ###
  tableFields: (fields, options) ->
    _fields = []
    for fieldName, field of fields
      tableField =
        key: fieldName
        label: field.displayName
        isVisible: options.fieldVisibility[fieldName].get()
        sortOrder: options.sortOrder[fieldName].get()
        sortDirection: options.sortDirection[fieldName].get()
        sortable: field.sortable

      if field.displayFn
        tableField.fn = field.displayFn
      if field.sortFn
        tableField.sortFn = field.sortFn
      _fields.push(tableField)
    _fields

  ###
  # gotoEvent - navigates to a selected event
  #
  # @param {object} event, DOM event
  # @param {object} instance, template instance
  ###
  gotoEvent: (event, instance) ->
    route = "#{instance.data.eventType.get()}-event"
    if event.metaKey
      url = Router.url route, _id: @_id
      window.open(url, '_blank')
    else
      Router.go route, _id: @_id

  ###
  # scrollToTop - scrolls document to top of window
  ###
  scrollToTop: ->
    if window.scrollY > 0 and window.innerHeight < 700
      $(document.body).animate({scrollTop: 0}, 400)
