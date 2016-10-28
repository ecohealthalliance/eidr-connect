incidentReportSchema = require('/imports/schemas/incidentReport.coffee')
# A annotation's territory is the sentence containing it,
# and all the following sentences until the next annotation.
# Annotations in the same sentence are grouped.
getTerritories = (annotationsWithOffsets, sents) ->
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
      territories[territories.length - 1].territoryEnd = sentEnd
  return territories

# Parse text into an array of sentences separated by
# periods, colons, semi-colons, or double linebreaks.
parseSents = (text)->
  idx = 0
  sents = []
  sentStart = 0
  while idx < text.length
    char = text[idx]
    if char == "\n"
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
  return sents

Template.suggestedIncidentsModal.onCreated ->
  @incidentCollection = new Meteor.Collection(null)
  @loading = new ReactiveVar(true)
  @content = new ReactiveVar("")
  Meteor.call("getArticleEnhancements", @data.article.url, (error, result) =>
    if error
      Modal.hide(@)
      toastr.error error.reason
      return
    geonameIds = result.keypoints
      .filter((k)->k.location)
      .map((k)->k.location.geonameid)
    new Promise((resolve, reject) =>
      if geonameIds.length == 0
        resolve([])
      else
        HTTP.get("https://geoname-lookup.eha.io/api/geonames", {
          params:
            ids: geonameIds
        }, (error, geonamesResult) =>
          if error
            toastr.error error.reason
            Modal.hide(@)
            reject()
          else
            resolve(geonamesResult.data.docs)
        )
    ).then((locations) =>
      geonamesById = {}
      locations.forEach (loc)->
        geonamesById[loc.id] =
          id: loc.id
          name: loc.name
          admin1Name: loc.admin1Name
          admin2Name: loc.admin2Name
          latitude: parseFloat(loc.latitude)
          longitude: parseFloat(loc.longitude)
          countryName: loc.countryName
          population: loc.population
          featureClass: loc.featureClass
          featureCode: loc.featureCode
          alternateNames: loc.alternateNames
      @loading.set(false)
      @content.set result.source.cleanContent.content
      sents = parseSents(result.source.cleanContent.content)
      keypoints = result.keypoints
      locTerritories = getTerritories(keypoints.filter((keypoint)->keypoint.location), sents)
      dateKeypoints = keypoints
        .map (keypoint)=>
          time = keypoint.time
          if not time
            return
          if keypoint.time.label == "PRESENT_REF" or keypoint.text == "today"
            time.timeRange =
              begin: moment.utc(@data.article.publishDate).toObject()
              end: moment.utc(@data.article.publishDate).add(1, "day").toObject()
            time.precision = 1
            return keypoint
          if not (time.timeRange and time.timeRange.begin and time.timeRange.end)
            #console.log "No Timerange", keypoint
            return
          # moment parses 0 based month indecies
          if time.timeRange.begin.month then time.timeRange.begin.month--
          if time.timeRange.end.month then time.timeRange.end.month--
          time.precision = Object.keys(time.timeRange.end).length + Object.keys(time.timeRange.end).length
          return keypoint
        .filter (keypoint)-> keypoint
      dateTerritories = getTerritories(dateKeypoints, sents)
      result.keypoints.forEach((keypoint) =>
        unless keypoint.count then return
        [kStart, kEnd] = keypoint.textOffsets[0]
        locationTerritory = _.find locTerritories, ({territoryStart, territoryEnd})->
          if kStart <= territoryEnd and kStart >= territoryStart
            return true
        dateTerritory = _.find dateTerritories, ({territoryStart, territoryEnd})->
          if kStart <= territoryEnd and kStart >= territoryStart
            return true
        incident =
          locations: locationTerritory.annotations.map(({location})->geonamesById[location.geonameid])
        maxPrecision = 0
        dateTerritory.annotations.forEach (annotation)->
          time = annotation.time
          fromTime = _.clone(time.timeRange.begin)
          toTime = _.clone(time.timeRange.end)
          momentFromTime = moment.utc(fromTime)
          # Round up the to day end
          momentToTime = moment.utc(_.extend({hours:23, minutes: 59}, toTime))
          if time.precision > maxPrecision and momentToTime.isValid() and momentFromTime.isValid()
            maxPrecision = time.precision
            incident.dateRange =
              start: momentFromTime.toDate()
              end: momentToTime.toDate()
            if moment(incident.dateRange.end).diff(incident.dateRange.start, "hours") <= 24
              incident.dateRange.type = "day"
            else
              incident.dateRange.type = "precise"
        incident.dateTerritory = dateTerritory
        incident.locationTerritory = locationTerritory
        incident.countAnnotation = keypoint
        countValue = keypoint.count.number or keypoint.count.range_end
        if keypoint.count.case
          incident.cases = countValue
        else if keypoint.count.death
          incident.deaths = countValue
        # Detect whether count is cumulative
        if "incremental" of keypoint.count
          incident.dateRange.cumulative = not keypoint.count.incremental
        else if "cumulative" of keypoint.count
          incident.dateRange.cumulative = keypoint.count.cumulative
        else if incident.dateRange.type == "day" and countValue > 300
          incident.dateRange.cumulative = true
        incident.url = [@data.article.url]
        @incidentCollection.insert(incident)
      )
    )
  )
Template.suggestedIncidentsModal.helpers
  incidents: ->
    Template.instance().incidentCollection.find()
  incidentsFound: ->
    Template.instance().incidentCollection.find().count() > 0
  loading: ->
    Template.instance().loading.get()
  annotatedCount: ->
    total = Template.instance().incidentCollection.find().count()
    if total
      count = Template.instance().incidentCollection.find({accepted: true}).count()
      count + " of " + total + " incidents accepted"

  annotatedContent: ->
    content = Template.instance().content.get()
    lastEnd = 0
    html = ""
    Template.instance().incidentCollection.find().map (incident)->
      [start, end] = incident.countAnnotation.textOffsets[0]
      html += (
        Handlebars._escape("#{content.slice(lastEnd, start)}") +
        """<span
          class='annotation annotation-text#{if incident.accepted then " accepted" else ""}'
          data-incident-id='#{incident._id}'
        >#{Handlebars._escape(content.slice(start, end))}</span>"""
      )
      lastEnd = end
    html += Handlebars._escape("#{content.slice(lastEnd)}")
    new Spacebars.SafeString(html)

Template.suggestedIncidentsModal.events
  "click .annotation": (event, template) ->
    incident = template.incidentCollection.findOne($(event.target).data("incident-id"))
    content = Template.instance().content.get()
    displayCharacters = 150
    [start, end] = incident.countAnnotation.textOffsets[0]

    startingIndex = Math.min(incident.locationTerritory?.territoryStart or start,
      incident.dateTerritory?.territoryStart or start)
    precedingText = content.slice(startingIndex, start)

    if startingIndex isnt 0
      precedingText = "... " + precedingText

    endingIndex = Math.max(incident.locationTerritory?.territoryEnd or end,
      incident.dateTerritory?.territoryEnd or end)
    followingText = content.slice(end, endingIndex)

    # Split the following text if it contains multiple new lines
    split = followingText.split(/\n{2,}/g)
    if endingIndex isnt (content.length - 1)
      followingText += " ..."

    Modal.show("suggestedIncidentModal", {
      articles: [template.data.article]
      userEventId: template.data.userEventId
      incidentCollection: template.incidentCollection
      incident: incident
      incidentText: Spacebars.SafeString(Handlebars._escape(precedingText) + """<span class='annotation-text'>#{Handlebars._escape(content.slice(start, end))}</span>""" + Handlebars._escape(followingText))
    })
  "click #add-suggestions": (event, template) ->
    incidents = Template.instance().incidentCollection.find({accepted: true}).map (incident)->
      _.pick(incident, incidentReportSchema.objectKeys())
    Meteor.call "addIncidentReports", incidents, (err, result)->
      if err
        toastr.error err.reason
      else
        Modal.hide(template)
  "click #non-suggested-incident": (event, template) ->
    Modal.show("incidentModal", {
      articles: [template.data.article]
      userEventId: template.data.userEventId
      add: true
      incident: {url: [template.data.article.url]}
    })
