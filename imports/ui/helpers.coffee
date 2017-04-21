import { incidentTypeWithCountAndDisease, formatUrl } from '/imports/utils'

UI.registerHelper 'formatLocation', (location)->
  formatLocation(location)

UI.registerHelper 'formatLocations', (locations)->
  formatLocations(locations)

UI.registerHelper 'formatDateRange', (dateRange)->
  formatDateRange(dateRange)

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
  dateRange ?= ''
  start = moment.utc(dateRange.start)
  end = moment.utc(dateRange.end)
  dateFormatEnd = "MMM D, YYYY"
  dateFormatStart = dateFormatEnd
  inSameYear = start?.year() == end?.year()
  inSameMonthAndYear = inSameYear and start?.month() == end?.month()
  sameMonthAndYearDateRange =
    start.format('MMM D') + ' - ' + end.format('D') + ', ' + end.format('YYYY')
  if inSameYear
    dateFormatStart = "MMM D"
  startFormated = start.format(dateFormatStart)
  startFormatedWithYear = start.format(dateFormatEnd)
  endFormated = end.format(dateFormatEnd)

  if dateRange.type is "day"
    if dateRange.cumulative
      "before " + endFormated
    else
      if readable
        "on " + startFormatedWithYear
      else
        startFormatedWithYear
  else if dateRange.type is "precise"
    if readable
      "between " + startFormated + " and " + endFormated
    else if inSameMonthAndYear
      sameMonthAndYearDateRange
    else
      startFormated + " - " + endFormated
  else if inSameMonthAndYear
    sameMonthAndYearDateRange
  else
    startFormated + " - " + endFormated

export formatLocation = ({name, admin2Name, admin1Name, countryName}) ->
  _.chain([name, admin2Name, admin1Name, countryName])
    .compact()
    .uniq()
    .value()
    .join(", ")

export formatLocations = (locations) ->
  locations.map(formatLocation).join('; ')
