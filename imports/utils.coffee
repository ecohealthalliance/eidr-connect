import Constants from '/imports/constants.coffee'
import Articles from '/imports/collections/articles.coffee'
import { notify } from '/imports/ui/notification'

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
  if $form.find('#singleDate').hasClass('active')
    rangeType = 'day'
    $pickerContainer = $form.find('#singleDatePicker')
  else
    rangeType = 'precise'
    $pickerContainer = $form.find('#rangePicker')

  picker = $pickerContainer.data('daterangepicker')

  incidentType = $form.find('input[name="incidentType"]:checked').val()
  incidentStatus = $form.find('input[name="incidentStatus"]:checked').val()

  incident =
    travelRelated: form.travelRelated.checked
    approximate: form.approximate.checked
    locations: []
    status: incidentStatus
    species: null
    resolvedDisease: null
    dateRange:
      type: rangeType
      start: moment.utc(picker.startDate.format("YYYY-MM-DD")).toDate()
      end: moment.utc(picker.endDate.format("YYYY-MM-DD")).toDate()
      cumulative: form.cumulative.checked

  switch incidentType || ''
    when 'cases'
      incident.cases = parseInt(form.count.value, 10)
    when 'deaths'
      incident.deaths = parseInt(form.count.value, 10)
    when 'other'
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

# Parse text into an array of sentences separated by
# periods, colons, semi-colons, or double linebreaks.
export parseSents = (text) ->
  idx = 0
  sents = []
  sentStart = 0
  while idx < text.length
    char = text[idx]
    if char == '\n'
      [match] = text.slice(idx).match(/^\n+/)
      idx += match.length
      if match.length > 1
        sents[sents.length] = text.slice(sentStart, idx)
        sentStart = idx
    else if /^[\.\;\:]/.test(char)
      idx++
      sents[sents.length] = text.slice(sentStart, idx)
      sentStart = idx
    else
      idx++
  if sentStart < idx
    sents[sents.length] = text.slice(sentStart, idx)
  return sents

# A annotation's territory is the sentence containing it,
# and all the following sentences until the next annotation.
# Annotations in the same sentence are grouped.
export getTerritories = (annotationsWithOffsets, sents, options={}) ->
  # If the sentenceOnly option is turned on territories are limited
  # to the sentence containing the term.
  { sentenceOnly=false } = options
  # Split annotations with multiple offsets
  # and sort by offset.
  annotationsWithSingleOffsets = []
  annotationsWithOffsets.forEach (annotation) ->
    annotation.textOffsets.forEach (textOffset) ->
      splitAnnotation = Object.create(annotation)
      splitAnnotation.textOffsets = [textOffset]
      annotationsWithSingleOffsets.push(splitAnnotation)
  annotationsWithOffsets = _.sortBy(annotationsWithSingleOffsets, (annotation) ->
    annotation.textOffsets[0][0]
  )
  annotationIdx = 0
  sentStart = 0
  sentEnd = 0
  territories = []
  sents.forEach (sent) ->
    sentStart = sentEnd
    sentEnd = sentEnd + sent.length
    sentAnnotations = []
    while annotation = annotationsWithOffsets[annotationIdx]
      [aStart, aEnd] = annotation.textOffsets[0]
      if aStart > sentEnd
        break
      else
        sentAnnotations.push annotation
        annotationIdx++
    if sentAnnotations.length > 0 or territories.length == 0
      territories.push
        annotations: sentAnnotations
        territoryStart: sentStart
        territoryEnd: sentEnd
    else
      if sentenceOnly and territories[territories.length - 1].annotations.length > 0
        territories.push
          annotations: []
          territoryStart: sentStart
          territoryEnd: sentEnd
      else
        territories[territories.length - 1].territoryEnd = sentEnd
  return territories

export createIncidentReportsFromEnhancements = (enhancements, options) ->
  { countAnnotations, acceptByDefault, articleId, publishDate } = options
  if not publishDate
    publishDate = new Date()
  incidents = []
  features = enhancements.features
  locationAnnotations = features.filter (f) -> f.type == 'location'
  datetimeAnnotations = features.filter (f) -> f.type == 'datetime'
  diseaseAnnotations = features.filter (f) ->
    f.type == 'resolvedKeyword' and f.resolutions.some((r) ->
      r.entity.type == 'disease'
    )
  speciesAnnotations = features.filter (f) ->
    f.type == 'resolvedKeyword' and f.resolutions.some((r) ->
      r.entity.type == 'species'
    )
  if not countAnnotations
    countAnnotations = features.filter (f) -> f.type == 'count'
  sents = parseSents(enhancements.source.cleanContent.content)
  locTerritories = getTerritories(locationAnnotations, sents)
  datetimeAnnotations = datetimeAnnotations
    .map (timeAnnotation) =>
      if not (timeAnnotation.timeRange and
        timeAnnotation.timeRange.begin and
        timeAnnotation.timeRange.end
      )
        return
      # moment parses 0 based month indecies
      if timeAnnotation.timeRange.begin.month
        timeAnnotation.timeRange.begin.month--
      if timeAnnotation.timeRange.end.month
        timeAnnotation.timeRange.end.month--
      timeAnnotation.beginMoment = moment.utc(
        timeAnnotation.timeRange.begin
      )
      # Round up the to day end
      timeAnnotation.endMoment = moment.utc(
        timeAnnotation.timeRange.end
      ).endOf('day')
      if timeAnnotation.beginMoment > timeAnnotation.endMoment
        console.error("End date occurs before start date.")
        return
      publishMoment = moment.utc(publishDate)
      if timeAnnotation.beginMoment.isAfter publishMoment, 'day'
        # Omit future dates
        return
      if timeAnnotation.endMoment.isAfter publishMoment, 'day'
        # Truncate ranges that extend into the future
        timeAnnotation.endMoment = publishMoment
      return timeAnnotation
    .filter (x) -> x
  dateTerritories = getTerritories(datetimeAnnotations, sents)
  diseaseTerritories = getTerritories(diseaseAnnotations, sents)
  # Only include the sentence the word appears in for species territories since
  # the species is implicitly human in most of the articles we're analyzing.
  speciesTerritories = getTerritories(speciesAnnotations, sents, sentenceOnly: true)
  countAnnotations.forEach (countAnnotation) =>
    [start, end] = countAnnotation.textOffsets[0]
    locationTerritory = _.find locTerritories, ({territoryStart, territoryEnd}) ->
      start <= territoryEnd and start >= territoryStart
    dateTerritory = _.find dateTerritories, ({territoryStart, territoryEnd}) ->
      start <= territoryEnd and start >= territoryStart
    diseaseTerritory = _.find diseaseTerritories, ({territoryStart, territoryEnd}) ->
      start <= territoryEnd and start >= territoryStart
    speciesTerritory = _.find speciesTerritories, ({territoryStart, territoryEnd}) ->
      start <= territoryEnd and start >= territoryStart
    # grouping is done to deduplicate geonames
    locations = _.chain(locationTerritory.annotations)
      .pluck('geoname')
      .groupBy('id')
      .values()
      .map((x) -> x[0])
      .value()
    incident =
      locations: locations
    maxPrecision = Infinity
    # Use the document's date as the default
    incident.dateRange =
      start: publishDate
      end: moment(publishDate).add(1, 'day').toDate()
      type: 'day'
    dateTerritory.annotations.forEach (timeAnnotation) ->
      if (timeAnnotation.beginMoment.isValid() and
        timeAnnotation.endMoment.isValid()
      )
        precision = timeAnnotation.endMoment - timeAnnotation.beginMoment
        if precision < maxPrecision
          maxPrecision = timeAnnotation.precision
        else
          return
        incident.dateRange =
          start: timeAnnotation.beginMoment.toDate()
          end: timeAnnotation.endMoment.toDate()
        rangeHours = moment(incident.dateRange.end)
          .diff(incident.dateRange.start, 'hours')
        if rangeHours <= 24
          incident.dateRange.type = 'day'
        else
          incident.dateRange.type = 'precise'
    incident.dateTerritory = dateTerritory
    incident.locationTerritory = locationTerritory
    incident.diseaseTerritory = diseaseTerritory
    incident.speciesTerritory = speciesTerritory
    incident.countAnnotation = countAnnotation
    { count, attributes } = countAnnotation
    if count
      if 'death' in attributes
        incident.deaths = count
      else if "case" in attributes or "hospitalization" in attributes
        incident.cases = count
      else
        incident.cases = count
        incident.uncertainCountType = true
      if acceptByDefault and not incident.uncertainCountType
        incident.accepted = true
      # Detect whether count is cumulative
      if 'incremental' in attributes
        incident.dateRange.cumulative = false
      else if 'cumulative' in attributes
        incident.dateRange.cumulative = true
      else if incident.dateRange.type == 'day' and count > 300
        incident.dateRange.cumulative = true
      suspectedAttributes = _.intersection([
        'approximate', 'average', 'suspected'
      ], attributes)
      if suspectedAttributes.length > 0
        incident.status = 'suspected'
    incident.articleId = articleId
    # The disease field is set to the last disease mentioned.
    diseaseTerritory.annotations.forEach (annotation) ->
      incident.resolvedDisease =
        id: annotation.resolutions[0].entity.id
        text: annotation.resolutions[0].entity.label
    # Suggest humans as a default
    incident.species =
      id: "tsn:180092"
      text: "Homo sapiens"
    speciesTerritory.annotations.forEach (annotation) ->
      incident.species =
        id: annotation.resolutions[0].entity.id
        text: annotation.resolutions[0].entity.label
    incident.suggestedFields = _.intersection(
      Object.keys(incident),
      [
        'resolvedDisease'
        'species'
        'cases'
        'deaths'
        'dateRange'
        'status'
        if incident.locations.length then 'locations'
      ]
    )
    if incident.dateRange?.cumulative
      incident.suggestedFields.push('cumulative')

    annotations =
      case: [
        textOffsets: incident.countAnnotation.textOffsets[0]
        text: incident.countAnnotation.text
      ]
    if locationTerritory.annotations.length
      annotations.location =
        locationTerritory.annotations.map (a) -> textOffsets: a.textOffsets[0]
    if dateTerritory.annotations.length
      annotations.date =
        dateTerritory.annotations.map (a) -> textOffsets: a.textOffsets[0]
    if diseaseTerritory.annotations.length
      annotations.disease =
        diseaseTerritory.annotations.map (a) -> textOffsets: a.textOffsets[0]
    incident.annotations = annotations
    incident.autogenerated = true
    incidents.push(incident)
  return incidents

export incidentTypeWithCountAndDisease = (incident) ->
  text = ''
  cases = incident.cases
  deaths = incident.deaths
  specify = incident.specify
  disease = incident.resolvedDisease?.text
  if cases >= 0
    text = "#{cases} #{pluralize('case', cases, false)}"
  else if deaths >= 0
    text = "#{deaths} #{pluralize('death', deaths, false)}"
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
  if not dateRange or not (dateRange.start or dateRange.end)
    return
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
