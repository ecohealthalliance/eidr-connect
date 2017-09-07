import Articles from '/imports/collections/articles'
import { documentTitle } from '/imports/utils'

Template.eventReferences.helpers
  documents: ->
    Articles.find()

  settings: ->
    fields = [
      {
        key: 'title'
        label: 'Title'
        fn: (value, object, key) ->
          documentTitle(object)
      }
      {
        key: 'publishDate'
        label: 'Publish Date'
        fn: (value, object, key) ->
          if value then moment.utc(value).format('MMM D, YYYY')
        sortFn: (value, object) ->
          +new Date(value)
      }
      {
        key: 'addedDate'
        label: 'Added Date'
        fn: (value, object, key) -> moment.utc(value).format('MMM D, YYYY')
        sortFn: (value, object) ->
          +new Date(value)
      }
      {
        key: 'addedByUserName'
        label: 'Added By'
      }
    ]
    fields: fields
    showFilter: false
    showNavigationRowsPerPage: false
    showRowCount: false
    class: 'table documents static-rows'
    rowClass: 'document'
    keyboardFocus: false
