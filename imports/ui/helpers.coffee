import { incidentTypeWithCountAndDisease, formatUrl } from '/imports/utils'

UI.registerHelper 'formatLocation', (location)->
  return formatLocation(location)

UI.registerHelper 'formatLocations', (locations)->
  return locations.map(formatLocation).join('; ')

UI.registerHelper 'formatDateRange', (dateRange)->
  return formatDateRange(dateRange)

UI.registerHelper 'incidentToText', (incident) ->
  if @cases
    incidentDescription = pluralize("case", @cases)
  else if @deaths
    incidentDescription = pluralize("death", @deaths)
  else if @specify
    incidentDescription = @specify
  if @locations.length < 2
    formattedLocations = formatLocation(@locations[0])
  else
    formattedLocations = (
      @locations.map(formatLocation).slice(0, -1).join(", ") +
      ", and " + formatLocation(@locations.slice(-1)[0])
    )

  result = """
    <span>#{incidentDescription}</span> in <span>#{formattedLocations}</span>
  """
  if @dateRange
    result += "<span> #{formatDateRange(@dateRange, true)}</span>"
  Spacebars.SafeString result


UI.registerHelper 'incidentCountAndDisease', ->
  incidentTypeWithCountAndDisease(@)

UI.registerHelper 'formatDate', (date) ->
  moment(date).format("MMM DD, YYYY")

UI.registerHelper 'formatDateISO', (date) ->
  moment.utc(date).format("YYYY-MM-DDTHH:mm")

UI.registerHelper 'formatUrl', (url) ->
  formatUrl(url)

export pluralize = (word, count, showCount=true) ->
  if Number(count) isnt 1
    word += "s"
  if showCount then "#{count} #{word}" else word

export formatDateRange = (dateRange, readable)->
  dateFormat = "MMM D, YYYY"
  dateRange ?= ''
  if dateRange.type is "day"
    if dateRange.cumulative
      return "before " + moment.utc(dateRange.end).format(dateFormat)
    else
      if readable
        return "on " + moment.utc(dateRange.start).format(dateFormat)
      else
        return moment.utc(dateRange.start).format(dateFormat)
  else if dateRange.type is "precise"
    if readable
      return "between " + moment.utc(dateRange.start).format(dateFormat) + " and " + moment.utc(dateRange.end).format(dateFormat)
    else
      return moment.utc(dateRange.start).format(dateFormat) + " - " + moment.utc(dateRange.end).format(dateFormat)
  else
    return moment.utc(dateRange.start).format(dateFormat) + " - " + moment.utc(dateRange.end).format(dateFormat)

export formatLocation = ({name, admin2Name, admin1Name, countryName}) ->
  return _.chain([name, admin2Name, admin1Name, countryName])
    .compact()
    .uniq()
    .value()
    .join(", ")
