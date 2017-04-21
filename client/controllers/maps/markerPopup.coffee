import { pluralize } from '/imports/ui/helpers'

Template.markerPopup.helpers
  getEvents: () ->
    Template.instance().data.events

  getMostSevere: (incidents) ->
    instance = Template.instance()
    byLocation = _.chain(incidents)
      .filter (incident) ->
        locationNames = _.pluck(incident.locations, 'name')
        if locationNames.indexOf(instance.data.location) >= 0
          count = 0
          # we only look as cases
          if typeof incident.cases != 'undefined'
            count += incident.cases
            incident.type = pluralize('case', count, false)
          if count > 0
            incident.count = count
            incident
      .sortBy (incident) ->
        -incident.count
      .value()
    if byLocation.length <= 0
      return {}
    if byLocation[0].count <= 0
      return {}
    byLocation[0]

  formatDate: (d) ->
    moment(d).format('MMM D, YYYY')
