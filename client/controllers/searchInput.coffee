###
 Seach input options/settings:
    textFilter:  Either a reactiveVar or ReactiveTableFilter
    id:          The id associated with the element and ReactiveTableFilter if its passed
    props:       If a textFilter is null, a ReactiveTableFilter will be created
                 with the id and props (an array)
    toggleable:  If set to true, the input will be initially hidden and appear when
                 the search icon is clicked. When the user clicks on the search
                 icon within the input, the input returns to its hidden state.
    placeholder: Defaults to 'Search'
    classes:     Classes which will be applied to the input's parent element
####
{ regexEscape } = require '/imports/utils'

clearSearch = (instance) ->
  instance.textFilter.set('')
  instance.$('.search').val('')

Template.searchInput.onRendered ->
  clearSearch(@)

Template.searchInput.onCreated ->
  instanceData = @data
  searching = true
  if instanceData.toggleable
    searching = false
  @searching = new ReactiveVar(searching)
  @textFilter = instanceData.textFilter or new ReactiveTable.Filter(instanceData.id, instanceData.props)

Template.searchInput.helpers
  searchString: ->
    Template.instance().textFilter.get()

  searchWaiting: ->
    Template.instance().searching.get()

  toggleable: ->
    Template.instance().data.toggleable

  placeholder: ->
    @placeholder or 'Search'

Template.searchInput.events
  'keyup .search, input .search': (event, instance) ->
    if event.type is 'keyup' and event.keyCode is 27
      clearSearch(instance)
    else
      instance.textFilter.set
        $regex: regexEscape(instance.$(event.target).val())
        $options: 'i'

  'focusin .search-icon.toggleable:not(.cancel)': (event, instance) ->
    focus = event.type is 'focusin'
    searching = instance.searching
    searching.set(not searching.get())
    setTimeout ->
      instance.$(".search").focus()
    , 200
    $(event.currentTarget).tooltip 'destroy'

  'click .cancel, keyup .search': (event, instance) ->
    return if event.type is 'keyup' and event.keyCode isnt 27
    clearSearch(instance)
