UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
PromedPosts = require '/imports/collections/promedPosts.coffee'

import { formatUrl } from '/imports/utils.coffee'


DateRegEx = /<span class="blue">Published Date:<\/span> ([^<]+)/

GRITS_API_URL = process.env.GRITS_API_URL or "https://grits.eha.io/api/v1"
SPA_API_URL = process.env.SPA_API_URL or "http://spa.eha.io/api/v1"

Meteor.methods
  getArticleEnhancements: (url) ->
    check url, String
    geonameIds = []
    console.log "Calling GRITS API @ " + GRITS_API_URL
    result = HTTP.post(GRITS_API_URL + "/public_diagnose", {
      params:
        api_key: "Cr9LPAtL"
        returnSourceContent: true
        showKeypoints: true
        # formatUrl takes a database cleanUrl and adds 'http://'
        url: formatUrl(url)
    })
    if result.data.error
      throw new Meteor.Error("grits-error", result.data.error)
    return result.data

  retrieveProMedArticleDate: (articleId) ->
    return PromedPosts.findOne(promedId: "" + articleId)?.promedDate

  queryForSuggestedArticles: (eventId) ->
    check eventId, String
    event = UserEvents.findOne(eventId)
    console.log "Calling SPA API @ " + SPA_API_URL
    unless event
      throw new Meteor.Error 404, "Unable to fetch the requested event record"
    # Construct an array of keywords out of the event's name
    keywords = _.uniq event.eventName.match(/\w{3,}/g)
    # Add the disease name from the event to the keywords
    if event.disease
      keywords.push(event.disease)
    # Collect related event source ID's
    notOneOfThese = []
    Articles.find(userEventId: eventId).forEach (relatedEventSource) ->
      url = relatedEventSource.url
      if url
        notOneOfThese.push url.match(/\d+/)?[0]
    # Query the remote server API
    response = HTTP.call('GET', "#{SPA_API_URL}/search", {
      params: { text: keywords.join(' '), not: notOneOfThese.join(' ') }
    })
    if response
      response.data
    else
      throw new Meteor.Error 500, "Unable to reach the API"

  ###
  # searchUserEvents - perform a full-text search on `eventName` and `summary`,
  #   sorted by matching score.
  #
  # @param {string} search, the text to search for matches
  # @returns {array} userEvents, an array of userEvents
  ###
  searchUserEvents: (search) ->
    UserEvents.find({$text: {$search: search}}, {fields: {score: {$meta: 'textScore'}}, sort: {score: {$meta: 'textScore'}}}).fetch()
