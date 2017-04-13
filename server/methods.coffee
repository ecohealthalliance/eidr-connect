UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
PromedPosts = require '/imports/collections/promedPosts.coffee'
Constants = require '/imports/constants.coffee'
Incidents = require '/imports/collections/incidentReports'
SmartEvents = require '/imports/collections/smartEvents'
incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
import { formatUrl, cleanUrl, createIncidentReportsFromEnhancements, regexEscape } from '/imports/utils.coffee'

DateRegEx = /<span class="blue">Published Date:<\/span> ([^<]+)/

Meteor.methods
  getArticleEnhancements: (article, options={}) ->
    @unblock()
    check article.url, Match.Maybe(String)
    check article.content, Match.Maybe(String)
    check article.publishDate, Match.Maybe(Date)
    check article.addedDate, Match.Maybe(Date)
    if not options.hideLogs
      console.log "Calling GRITS API @ " + Constants.GRITS_URL
    params =
      api_key: Constants.GRITS_API_KEY
      returnSourceContent: true
      priority: options.priority != false
    if article.publishDate or article.addedDate
      params.content_date = moment.utc(
        article.publishDate or article.addedDate
      ).utc().format("YYYY-MM-DDTHH:mm:ss")
    if article.content
      params.content = article.content
    else if article.url
      # formatUrl takes a database cleanUrl and adds 'http://'
      params.url = formatUrl(article.url)
    else
      Meteor.Error("InvalidArticle", "Content or a URL must be specified")
    result = HTTP.post(Constants.GRITS_URL + "/api/v1/public_diagnose", params: params)
    if result.data.error
      throw new Meteor.Error("grits-error", result.data.error)
    enhancements = result.data
    # Normalize geoname data in GRITS annotations to match incident schema.
    # The geoname lookup service is queried to get admin names.
    # The GRITS api reponse only includes admin codes at the moment.
    geonameIds = []
    features = enhancements.features
    locationAnnotations = features.filter (f) -> f.type == 'location'
    geonameIds = locationAnnotations.map((r) -> r.geoname.geonameid)
    if geonameIds.length > 0
      geonamesResult = HTTP.get Constants.GRITS_URL + '/api/geoname_lookup/api/geonames', {
        params:
          ids: geonameIds
      }
      geonames = geonamesResult.data.docs
      geonamesById = {}
      geonames.forEach (geoname) ->
        if not geoname
          # null geonames are returned when an id doesn't match a geoname
          # in the geoname lookup service's database.
          return
        geonamesById[geoname.id] =
          id: geoname.id
          name: geoname.name
          admin1Name: geoname.admin1Name
          admin2Name: geoname.admin2Name
          latitude: parseFloat(geoname.latitude)
          longitude: parseFloat(geoname.longitude)
          countryName: geoname.countryName
          population: geoname.population
          featureClass: geoname.featureClass
          featureCode: geoname.featureCode
          alternateNames: geoname.alternateNames
      locationAnnotations = locationAnnotations.filter (loc)->
        geoname = geonamesById[loc.geoname.geonameid]
        if geoname
          loc.geoname = geoname
          true
        else
          console.log "Missing geoname for id: " + loc.geoname.geonameid
          false
    return enhancements

  # Get the articles enhancements then use them to update the article
  # and create incidents in the database.
  getArticleEnhancementsAndUpdate: (article, options={}) ->
    dbArticle = Articles.findOne(_id: article._id)
    if not dbArticle
      throw Meteor.Error('invalid-article')
    if dbArticle.enhancements and not options.rediagnose
      if dbArticle.enhancements.processingStartedAt
        # If the processing started less than 100 seconds ago do not resubmit
        # the aritcle.
        if (new Date() - dbArticle.enhancements.processingStartedAt) < 100000
          return dbArticle.enhancements
      else
        return dbArticle.enhancements
    # Set the enhancements property to prevent repeated calls
    Articles.update _id: article._id,
      $set:
        enhancements: { processingStartedAt: new Date() }
    try
      enhancements = Meteor.call('getArticleEnhancements', article, options)
      Articles.update _id: article._id,
        $set:
          enhancements: enhancements
      article.enhancements = enhancements
      Meteor.call 'addSourceIncidentReportsToCollection', article, {
        acceptByDefault: true
      }
      return enhancements
    catch e
      Articles.update _id: article._id,
        $set:
          enhancements:
            error: "" + e
      throw e

  retrieveProMedArticle: (articleId) ->
    @unblock()
    article = PromedPosts.findOne
      promedId: "#{articleId}"

    promedDate: article.promedDate
    url: "http://www.promedmail.org/post/#{article.promedId}"
    subject: article.subject.raw

  queryForSuggestedArticles: (eventId) ->
    @unblock()
    check eventId, String
    event = UserEvents.findOne(eventId)
    console.log "Calling SPA API @ " + Constants.SPA_API_URL
    unless event
      throw new Meteor.Error 404, "Unable to fetch the requested event record"
    # Construct an array of keywords out of the event's name
    keywords = _.uniq event.eventName.match(/\w{3,}/g)
    # Add the disease name from the event to the keywords
    if event.disease
      keywords.push(event.disease)
    # Collect related event document ID's
    notOneOfThese = []
    Articles.find(userEventId: eventId).forEach (relatedEventSource) ->
      url = relatedEventSource.url
      if url
        notOneOfThese.push url.match(/\d+/)?[0]
    # Query the remote server API
    response = HTTP.call('GET', "#{Constants.SPA_API_URL}/search", {
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
    @unblock()
    UserEvents.find({
      $text:
        $search: search
      deleted: {$in: [null, false]}
    }, {
        fields:
          score:
            $meta: 'textScore'
        sort:
          score:
            $meta: 'textScore'
    }).fetch()

  ###
  # Create or update an EIDR-C meteor account for a BSVE user with the given
  # authentication info.
  # @param authInfo.authTicket - The BSVE authTicket used to verify the account
  #   with the BSVE. The EIDR-C user's password is set to the authTicket.
  # @param authInfo.user - The BSVE user's username. The EIDR-C username
  #   is the BSVE username with bsve- prepended.
  ###
  SetBSVEAuthTicketPassword: (authInfo)->
    # The api path chosen here is aribitrary, the call is only to verify that
    # the auth ticket works.
    response = HTTP.get("https://api.bsvecosystem.net/data/v2/sources/PON", {
      headers:
        "harbinger-auth-ticket": authInfo.authTicket
    })
    if Meteor.settings.private?.disableBSVEAuthentication
      throw new Meteor.Error("BSVEAuthFailure", "BSVE Authentication is disabled.")
    if response.data.status != 1
      throw new Meteor.Error("BSVEAuthFailure", response.data.message)
    meteorUser = Accounts.findUserByUsername("bsve-" + authInfo.user)
    if not meteorUser
      console.log "Creating user"
      {firstName, lastName} = authInfo.userData
      userId = Accounts.createUser(
        username: "bsve-" + authInfo.user
        profile:
          name: firstName + " " + lastName
      )
    else
      userId = meteorUser._id
    Roles.addUsersToRoles([userId], ['admin'])
    Accounts.setPassword(userId, authInfo.authTicket, logout:false)

  addSourceIncidentReportsToCollection: (source, options) ->
    { acceptByDefault } = options
    enhancements = source.enhancements
    check enhancements, Object
    options.articleId = source._id
    options.publishDate = source.publishDate
    incidents = createIncidentReportsFromEnhancements(enhancements, options)
    incidents = incidents.map (incident) ->
      incident = _.pick(incident, incidentReportSchema.objectKeys())
    # check for unexpected urls
    # if not options.url.startsWith("promedmail.org/post/")
    #   throw Meteor.Error("Bad url")
    # Remove prior unassociated incidents for the document
    Incidents.remove
      articleId: source._id
      userEventId: $exists: false
      autogenerated: $ne: false
    incidents.forEach (incident)->
      incidentReportSchema.validate(incident)
      incident.addedDate = new Date()
      # The addedByUser____ fields are left empty on autogenerated incidents.
      Incidents.insert(incident)
