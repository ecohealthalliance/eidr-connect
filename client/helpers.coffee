import {
  incidentTypeWithCountAndDisease,
  formatUrl,
  pluralize,
  formatDateRange,
  formatLocation,
  formatLocations } from '/imports/utils'

UI.registerHelper 'formatLocation', (location)->
  formatLocation(location)

UI.registerHelper 'formatLocations', (locations)->
  formatLocations(locations)

UI.registerHelper 'formatDateRange', (dateRange)->
  formatDateRange(dateRange)

UI.registerHelper 'incidentToText', (incident) ->
  if incident.cases
    incidentDescription = pluralize("case", incident.cases)
  else if incident.deaths
    incidentDescription = pluralize("death", incident.deaths)
  else if incident.specify
    incidentDescription = incident.specify
  if incident.locations.length < 2
    formattedLocations = formatLocation(incident.locations[0])
  else
    formattedLocations = (
      incident.locations.map(formatLocation).slice(0, -1).join(", ") +
      ", and " + formatLocation(incident.locations.slice(-1)[0])
    )

  result = """
    <span>#{incidentDescription}</span> in <span>#{formattedLocations}</span>
  """
  if incident.dateRange
    result += "<span> #{formatDateRange(incident.dateRange, true)}</span>"
  Spacebars.SafeString result


UI.registerHelper 'incidentCountAndDisease', (incident)->
  incidentTypeWithCountAndDisease(incident)

UI.registerHelper 'formatDate', (date=null) ->
  moment(date).format("MMM DD, YYYY")

UI.registerHelper 'formatDateISO', (date=null) ->
  moment.utc(date).format("YYYY-MM-DDTHH:mm")

UI.registerHelper 'formatUrl', (url) ->
  formatUrl(url)
