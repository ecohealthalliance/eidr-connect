import Constants from '/imports/constants'
import Articles from '/imports/collections/articles'
import notify from '/imports/ui/notification'
import regionToCountries from '/imports/regionToCountries.json'
import diseaseToSubtypes from '/imports/diseaseToSubtypes.json'

###
# cleanUrl - takes an existing url and removes the last match of the applied
#   regular expressions.
#
# @param {string} existingUrl, the url to be cleaned
# @param {array} [regexps], (optional) an array of compiled regular expressions
# @returns {string} cleanedUrl, an url that has been cleaned
###
export cleanUrl = (existingUrl, regexps) ->
  regexps = regexps || [new RegExp('^(https?:\/\/)', 'i'), new RegExp('^(www\.)', 'i')]
  cleanedUrl = existingUrl
  regexps.forEach (r) ->
    found = false
    match = cleanedUrl.match(r)
    if match && match.length > 0
      cleanedUrl = cleanedUrl.replace(match[match.length-1], '')
  return cleanedUrl

###
# formatUrl - takes an cleaned url and adds 'http' so that a browser can open
#
# @param {string} existingUrl, the url to be formatted
# @returns {string} formattedUrl, an url that has 'http' added
###
export formatUrl = (existingUrl) ->
  if existingUrl
    regexp = new RegExp('^(https?:\/\/)', 'i')
    if regexp.test existingUrl
      return existingUrl
    else
      return 'http://' + existingUrl

checkIncidentTypeValue = (form, input) ->
  if not form[input].value.trim()
    messageText = 'count'
    if input is 'specify'
      messageText = 'incident type'
    notify('error', "Please enter a valid #{messageText}.")
    false
  else
    true

export incidentReportFormToIncident = (form) ->
  $form = $(form)
  incidentType = form.type.value
  incidentStatus = $form.find('input[name="incidentStatus"]:checked').val()

  if $form.find('#singleDate').hasClass('active')
    rangeType = 'day'
    $pickerContainer = $form.find('#singleDatePicker')
  else if $form.find('#preciseRange').hasClass('active')
    rangeType = 'precise'
    $pickerContainer = $form.find('#rangePicker')
  else
    rangeType = 'none'

  dateRange = null
  if rangeType != 'none'
    picker = $pickerContainer.data('daterangepicker')
    dateRange = 
      type: rangeType
      start: moment.utc(picker.startDate.format("YYYY-MM-DD")).toDate()
      # Add a day because the human formatted date ranges include the last
      # day in the range while in the internal representation the end is the
      # time interval's end-point.
      end: moment.utc(picker.endDate.format("YYYY-MM-DD")).add(1, 'days').toDate()
      cumulative: incidentType.startsWith("cumulative")

  incident =
    type: incidentType
    travelRelated: form.travelRelated.checked
    approximate: form.approximate.checked
    locations: []
    status: incidentStatus
    species: null
    resolvedDisease: null
    dateRange: dateRange

  switch incidentType || ''
    when 'caseCount'
      incident.cases = parseInt(form.count.value, 10)
    when 'deathCount'
      incident.deaths = parseInt(form.count.value, 10)
    when 'cumulativeCaseCount'
      incident.cases = parseInt(form.count.value, 10)
    when 'cumulativeDeathCount'
      incident.deaths = parseInt(form.count.value, 10)
    when 'activeCount'
      incident.cases = parseInt(form.count.value, 10)
    when 'specify'
      incident.specify = form.specify.value.trim()
    else
      notify('error', "Unknown incident type [#{incidentType}]")
      return

  articleId = form.articleId?.value
  sourceSelect2Data = $(form.articleSource)?.select2('data')
  if not articleId and sourceSelect2Data
    for child in sourceSelect2Data
      if child.selected
        articleId = child.id
  incident.articleId = articleId

  for option in $(form).find('#incident-disease-select2').select2('data')
    incident.resolvedDisease =
      id: option.id
      text: option?.item?.label or option.text
  for option in $(form).find('#incident-species-select2').select2('data')
    incident.species =
      id: option.id
      text: option?.item?.completeName or option.text
  for option in $(form).find('#incident-location-select2').select2('data')
    item = option.item
    if typeof item.alternateNames is 'string'
      delete item.alternateNames
    incident.locations.push(item)
  return incident

export UTCOffsets =
  ADT:  '-0300'
  AKDT: '-0800'
  AKST: '-0900'
  AST:  '-0400'
  CDT:  '-0500'
  CST:  '-0600'
  EDT:  '-0400'
  EGST: '+0000'
  EGT:  '-0100'
  EST:  '-0500'
  HADT: '-0900'
  HAST: '-1000'
  MDT:  '-0600'
  MST:  '-0700'
  NDT:  '-0230'
  NST:  '-0330'
  PDT:  '-0700'
  PMDT: '-0200'
  PMST: '-0300'
  PST:  '-0800'
  WGST: '-0200'
  WGT: '-0300'

export capitalize = (s) ->
  s.charAt(0).toUpperCase() + s.substring(1)

export camelize = (s) ->
  s.split("_").map((word, idx) ->
    if idx == 0 then word else capitalize(word)
  ).join("")

export regexEscape = (s) ->
  # Based on bobince's regex escape function.
  # source: http://stackoverflow.com/questions/3561493/is-there-a-regexp-escape-function-in-javascript/3561711#3561711
  s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')

export keyboardSelect = (event) ->
  keyCode = event.keyCode
  keyCode in [13, 32]

export removeSuggestedProperties = (instance, props) ->
  suggestedFields = instance.suggestedFields
  if typeof props is 'string'
    suggestedFields.set([])
    return
  suggestedFields.set(_.difference(suggestedFields.get(), props))

export diseaseOptionsFn = (params, callback) ->
  term = params.term?.trim()
  if not term
    return callback(results: [])
  Meteor.call 'searchDiseaseNames', term, (error, response) ->
    if error
      return callback(error)
    callback(
      results: response.data.result.map((d) ->
        if d.synonym != d.label
          text = d.synonym + " | " + d.label
        else
          text = d.label
        {
          id: d.id
          text: text
          item: d
        }
      ).concat([
        id: "userSpecifiedDisease:#{term}"
        text: "Other Disease: #{term}"
      ])
    )

export speciesOptionsFn = (params, callback) ->
  term = params.term?.trim()
  if not term
    return callback(results: [])
  Meteor.call 'searchSpeciesNames', term, (error, results) ->
    if error
      notify('error', error.reason)
    callback(
      results: results.map((item) ->
        text = item.completeName
        if (new RegExp(term, "i")).test(item.vernacularName)
          text = item.vernacularName + " | " + item.completeName
        {
          id: 'tsn:' + item.tsn
          text: text
          item: item
        }
      ).concat([
        id: "userSpecifiedSpecies:#{term}"
        text: "Other Species: #{term}"
      ])
    )

export incidentTypeWithCountAndDisease = (incident) ->
  text = ''
  cases = incident.cases
  deaths = incident.deaths
  specify = incident.specify
  disease = incident.resolvedDisease?.text
  cumulativeStr = ""
  if incident.dateRange.cumulative
    cumulativeStr = "cumulative "
  if cases >= 0
    text = "#{cases} #{cumulativeStr}#{pluralize('case', cases, false)}"
  else if deaths >= 0
    text = "#{deaths} #{cumulativeStr}#{pluralize('death', deaths, false)}"
  else if specify
    text = specify
  else
    text = ''
  if disease and not specify
    if text
      text += ' of '
    text += "<span class='disease-name'>#{disease}</span>"
  Spacebars.SafeString(text)

###
# prevents checking the scrollTop more than every 50 ms to avoid flicker
# if the scrollTop is greater than zero, show the 'back-to-top' button
#
# @param [object] scrollableElement, the dom element from the scroll event
###
export debounceCheckTop = _.debounce ($scrollableElement, $toTopButton) ->
  top = $scrollableElement.scrollTop()
  offCanvas = $toTopButton.hasClass('off-canvas')
  containerHeight = window.innerHeight - $('header nav').height()
  # Show element when scroll distance from top is above containerHeight
  if top > containerHeight
    return if not offCanvas
    $toTopButton.removeClass('off-canvas')
    $toTopButton.addClass('on-canvas')
  else if top < 50 # Hide element when scroll distance from top is near top
    return if offCanvas
    $toTopButton.removeClass('on-canvas')
    $toTopButton.addClass('off-canvas')
, 50

export pluralize = (word, count, showCount=true) ->
  if Number(count) isnt 1
    word += "s"
  if showCount then "#{count} #{word}" else word

export formatDateRange = (dateRange, readable) ->
  # Prevent passing of template context object to be interpreted as true
  readable = readable == true
  DATE_FORMAT = "MMM D, YYYY"
  if not dateRange or not (dateRange.start or dateRange.end)
    return
  if not dateRange.end
    return "on or after " + moment.utc(dateRange.start).format(DATE_FORMAT)
  # Formatted date ranges include the final date in the range.
  # Ex: "June 1 - June 2" goes from the start of June 1 to the end of June 2.
  # The end timestamp in the range will be at the start of the next day.
  # A minute is subtracted from it so that it is on the final day in the range
  # when it is formatted.
  end = moment.utc(dateRange.end).subtract(1, 'minute')
  if not dateRange.start or dateRange.cumulative
    return "on or before " + moment.utc(end).format(DATE_FORMAT)
  start = moment.utc(dateRange.start)
  type = dateRange.type or "precise"
  if start.format(DATE_FORMAT) == end.format(DATE_FORMAT)
    type = "day"

  if type is "day"
    if readable
      return "on " + start.format(DATE_FORMAT)
    else
      return start.format(DATE_FORMAT)
  else if type is "precise"
    startFormated = start.format(DATE_FORMAT)
    if start.year() == end.year()
      startFormated = start.format("MMM D")
    endFormated = end.format(DATE_FORMAT)
    if readable
      return "between " + startFormated + " and " + endFormated
    else if start.format("MMM YYYY") == end.format("MMM YYYY")
      return start.format('MMM D') + ' - ' + end.format('D, YYYY')
    else
      return startFormated + " - " + endFormated

export formatLocation = (locations) ->
  return unless locations
  {name, admin2Name, admin1Name, countryName} = locations
  _.chain([name, admin2Name, admin1Name, countryName])
    .compact()
    .uniq()
    .value()
    .join(", ")

export formatLocations = (locations) ->
  locations.map(formatLocation).join('; ')

export documentTitle = (doc) ->
  doc.title or doc.url or (doc.content?.slice(0,30) + "...")

export eventToIncidentQuery = (event) ->
  query =
    accepted: $in: [null, true]
    deleted: $in: [null, false]
    locations: $not: $size: 0
  if event.diseases and event.diseases.length > 0
    query['resolvedDisease.id'] =
      $in: _.flatten(event.diseases.map (x) ->
        (diseaseToSubtypes[x.id] or []).concat([x.id])
      )
  eventDateRange = event.dateRange
  if eventDateRange
    if eventDateRange.end
      query['dateRange.start'] = $lte: eventDateRange.end
    if eventDateRange.start
      query['dateRange.end'] = $gte: eventDateRange.start
  locationQueries = []
  for location in (event.locations or [])
    locationQueries.push
      id: location.id
    if location.id of regionToCountries
      locationQueries.push
        countryCode: $in: regionToCountries[location.id].countryISOs
      continue
    locationQuery =
      countryName: location.countryName
    featureCode = location.featureCode
    if featureCode.startsWith("PCL")
      locationQueries.push(locationQuery)
    else
      locationQuery.admin1Name = location.admin1Name
      if featureCode is 'ADM1'
        locationQueries.push(locationQuery)
      else
        locationQuery.admin2Name = location.admin2Name
        if featureCode is 'ADM2'
          locationQueries.push(locationQuery)
  locationQueries = locationQueries.map (locationQuery) ->
    result = {}
    for prop, value of locationQuery
      result["locations.#{prop}"] = value
    return result
  if locationQueries.length > 0
    query['$or'] = locationQueries
  if event.species and event.species.length > 0
    query['species.id'] = $in: event.species.map (x) -> x.id
  query

mapAsync = (list, func, done)->
  if list.length > 0
    nextCb = (result)->
      mapAsync(list.slice(1), func, (nextResults)->
        done([result].concat(nextResults))
      )
    func(list[0], nextCb, done)
  else
    done([])

export mapAsync = mapAsync
export forEachAsync = mapAsync