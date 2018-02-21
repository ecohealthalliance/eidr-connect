import {
  pluralize,
  formatDateRange,
  formatLocations,
  incidentTypeWithCountAndDisease } from '/imports/utils'
import Articles from '/imports/collections/articles.coffee'
import Feeds from '/imports/collections/feeds.coffee'
import notify from '/imports/ui/notification'
import EventIncidents from '/imports/collections/eventIncidents'

Template.eventFeeds.onCreated ->
  @autorun =>
    sourceFeedsIds = {}
    EventIncidents.find(Template.instance().data.filterQuery.get()).map (incident) ->
      if incident.sourceFeed
        sourceFeedsIds[incident.sourceFeed] = incident.modifiedDate or incident.addedDate
    @subscribe('feeds', _id: $in: Object.keys(sourceFeedsIds))

Template.eventFeeds.helpers
  tableSettings: ->
    tableName = 'event-feeds'
    fields = [
      {
        key: 'title'
        label: 'Name'
      }
      {
        key: 'url'
        label: 'URL'
      }
      {
        key: 'addedDate'
        label: 'Last Updated'
        fn: (value, object, key) ->
          moment(value).format("MMM D, YYYY")
      }
    ]

    id: "#feed-table"
    fields: fields
    showFilter: false
    showNavigationRowsPerPage: false
    showRowCount: false

  tableCollection: ->
    Feeds.find().fetch()
