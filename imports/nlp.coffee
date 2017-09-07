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

# The number of characters between annotationA and annotationB.
annotationDistance = (annotationA, annotationB) ->
  [startA, endA] = annotationA.textOffsets[0]
  [startB, endB] = annotationB.textOffsets[0]
  if startA < startB
    return startB - endA
  else
    return startA - endB

nearestAnnotation = (annotation, otherAnnotations) ->
  nearest = null
  minDist = Infinity
  for otherAnnotation in otherAnnotations
    newDist = annotationDistance(otherAnnotation, annotation)
    console.assert(newDist < Infinity)
    if newDist < minDist
      minDist = newDist
      nearest = otherAnnotation
  return nearest

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
        console.log(timeAnnotation)
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
      start < territoryEnd and start >= territoryStart
    dateTerritory = _.find dateTerritories, ({territoryStart, territoryEnd}) ->
      start < territoryEnd and start >= territoryStart
    diseaseTerritory = _.find diseaseTerritories, ({territoryStart, territoryEnd}) ->
      start < territoryEnd and start >= territoryStart
    speciesTerritory = _.find speciesTerritories, ({territoryStart, territoryEnd}) ->
      start < territoryEnd and start >= territoryStart
    # grouping is done to deduplicate geonames
    locations = _.chain(locationTerritory.annotations)
      .pluck('geoname')
      .groupBy('id')
      .values()
      .map((x) -> x[0])
      .value()
    incident =
      locations: locations
    # Use the document's date as the default
    incident.dateRange =
      start: publishDate
      end: moment(publishDate).add(1, 'day').toDate()
      type: 'day'
    if dateTerritory.annotations.length > 0
      dateAnnotation = nearestAnnotation(
        countAnnotation, dateTerritory.annotations
      )
      incident.dateRange =
        start: dateAnnotation.beginMoment.toDate()
        end: dateAnnotation.endMoment.toDate()
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
      dateRangeHours = moment(incident.dateRange.end)
        .diff(incident.dateRange.start, 'hours')
      if 'incremental' in attributes
        incident.dateRange.cumulative = false
      else if 'cumulative' in attributes
        incident.dateRange.cumulative = true
      # Infer cumulative is case rate is greater than 300 per day
      else if (count / (dateRangeHours / 24)) > 300
        incident.dateRange.cumulative = true
      if incident.dateRange.cumulative
        if incident.cases
          incident.type = 'cumulativeCaseCount'
        else if incident.deaths
          incident.type = 'cumulativeDeathCount'
      else
        if "active" in attributes
          incident.type = 'activeCount'
        else if incident.cases
          incident.type = 'caseCount'
        else if incident.deaths
          incident.type = 'deathCount'
      suspectedAttributes = _.intersection([
        'approximate', 'average', 'suspected'
      ], attributes)
      if suspectedAttributes.length > 0
        incident.status = 'suspected'
    incident.articleId = articleId
    diseaseAnnotation = nearestAnnotation(countAnnotation, diseaseTerritory.annotations)
    if diseaseAnnotation
      incident.resolvedDisease =
        id: diseaseAnnotation.resolutions[0].entity.id
        text: diseaseAnnotation.resolutions[0].entity.label
    # Suggest humans as a default
    incident.species =
      id: "tsn:180092"
      text: "Homo sapiens"
    speciesAnnotation = nearestAnnotation(countAnnotation, speciesTerritory.annotations)
    if speciesAnnotation
      incident.species =
        id: speciesAnnotation.resolutions[0].entity.id
        text: speciesAnnotation.resolutions[0].entity.label
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