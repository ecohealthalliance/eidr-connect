import UserEvents from '/imports/collections/userEvents'
import Articles from '/imports/collections/articles'
import PromedPosts from '/imports/collections/promedPosts'
import Incidents from '/imports/collections/incidentReports'
import incidentReportSchema from '/imports/schemas/incidentReport'
import { formatUrl, capitalize, camelize } from '/imports/utils'
import { createIncidentReportsFromEnhancements } from '/imports/nlp'
import Constants from '/imports/constants'
import GeonameSchema from '/imports/schemas/geoname'
import sqlite3 from 'sqlite3'

DateRegEx = /<span class="blue">Published Date:<\/span> ([^<]+)/

speciesDB = new sqlite3.Database(
  Constants.SQLITE_DB_PATH,
  sqlite3.OPEN_READONLY,
  (error) ->
    if error
      console.log(error)
)

offsetsOverlap = ([aStart, aEnd], [bStart, bEnd]) ->
  (aStart >= bStart and aStart < bEnd) or (bStart >= aStart and bStart < aEnd)

# Create incidents for the given source document and add them to the incidents
# collection. If prior autogenerated incidents exist, those that are not
# associated with an event and have not been modified by an user will be
# removed. New incidents with counts that overlap the remaining prior incidents
# will not be added.
autogenerateDocumentIncidents = (source, options={}) ->
  { acceptByDefault, saveResults } = options
  enhancements = source.enhancements
  check(enhancements, Object)
  options.articleId = source._id
  options.publishDate = source.publishDate
  incidents = createIncidentReportsFromEnhancements(enhancements, options)
  incidents = incidents.map (incident) ->
    incident = incidentReportSchema.clean(incident)
  # Remove prior unassociated, unmodified incidents for the document
  priorIncidentIds = Incidents.find(
    articleId: source._id
    autogenerated: true
    modifiedByUserId: $in: [null, false]
  ).map((x) -> x._id)
  incidentEvents = UserEvents.find('incidents.id': $in: priorIncidentIds)
  associatedIncidentIds = _.flatten(incidentEvents.map((event) ->
    _.pluck(event.incidents, 'id')
  ))
  unassocaitedIncidentIds = _.difference(priorIncidentIds, associatedIncidentIds)
  Incidents.remove(_id: $in: unassocaitedIncidentIds)
  
  priorIncidentOffsets = Incidents.find(
    articleId: source._id
    annotations: $exists: true
  ).map (incident) ->
    incident.annotations.case[0].textOffsets
  incidents.forEach (incident) ->
    # Do not create new incidents that overlap old ones
    overlapsPriorIncident = priorIncidentOffsets.some (textOffsets) ->
      offsetsOverlap(incident.annotations.case[0].textOffsets, textOffsets)
    if not overlapsPriorIncident
      incidentReportSchema.validate(incident)
      incident.addedDate = new Date()
      # The addedByUser____ fields are left empty on autogenerated incidents.
      Incidents.insert(incident)

formatGeoname = (g) ->
  g = _.object(
    _.pairs(g).map(([k, v])->
      [camelize(k), v]
    )
  )
  g.id = g.geonameid
  delete g.geonameid
  delete g.nameCount
  delete g.namesUsed
  delete g.score
  g

Meteor.methods
  searchDiseaseNames: (term) ->
    check term, String
    HTTP.get Constants.GRITS_URL + "/api/v1/disease_ontology/lookup",
      params:
        q: term

  searchGeonames: (term) ->
    check term, String
    HTTP.get Constants.GRITS_URL + "/api/geoname_lookup/api/lookup",
      params:
        q: term

  searchSpeciesNames: (term) ->
    if not speciesDB.open
      return []
    # The data model for the itis database is available here:
    # https://www.itis.gov/pdf/ITIS_ConceptualModelEntityDefinition.pdf
    @unblock()
    if term.length < 2
      return []
    wrappedFn = Meteor.wrapAsync (callback) ->
      speciesDB.all("""SELECT
        tsn,
        min(completename) AS completeName,
        min(vernacular_name) AS vernacularName
      FROM longnames
      LEFT JOIN vernaculars USING (tsn)
      WHERE UPPER(vernacular_name) LIKE $term OR UPPER(completename) LIKE $term
      GROUP BY tsn
      ORDER BY
        CASE WHEN UPPER(vernacularName) LIKE $term
          THEN length(vernacularName)
          ELSE length(completeName) END
      ASC
      LIMIT 30;
      """, $term: "%" + term.toUpperCase() + "%", callback)
    wrappedFn()

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
    if not result.data
      throw new Meteor.Error("grits-error", "No response from GRITS server.")
    if result.data.error
      throw new Meteor.Error("grits-error", result.data.error)
    enhancements = result.data
    enhancements.features.forEach (f) ->
      if f.type == 'location'
        f.geoname = formatGeoname(f.geoname)
    enhancements.structuredIncidents = enhancements.structuredIncidents
      .filter (incident) ->
        incident.location and incident.dateRange
      .filter (incident) ->
        "Cannot parse" not in [incident.type, incident.dateRange, incident.location, incident.value]
      .map (incident) ->
        incident.location = formatGeoname(incident.location)
        incident
    return enhancements

  # Get the article's enhancements then use them to update the article
  # and create incidents in the database.
  getArticleEnhancementsAndUpdate: (articleId, options={}) ->
    dbArticle = Articles.findOne(_id: articleId)
    if not dbArticle
      throw Meteor.Error('invalid-article')
    if dbArticle.enhancements and not options.reprocess
      if dbArticle.enhancements.processingStartedAt
        # If the processing started less than 100 seconds ago do not resubmit
        # the aritcle.
        if (new Date() - dbArticle.enhancements.processingStartedAt) < 100000
          return dbArticle.enhancements
      else if not dbArticle.enhancements.error
        return dbArticle.enhancements
    # Set the enhancements property to prevent repeated calls
    Articles.update _id: articleId,
      $set:
        enhancements: { processingStartedAt: new Date() }
    try
      enhancements = Meteor.call('getArticleEnhancements', dbArticle, options)
      Articles.update _id: articleId,
        $set:
          enhancements: enhancements
      dbArticle.enhancements = enhancements
      autogenerateDocumentIncidents(dbArticle, {
        acceptByDefault: true
      })
      return enhancements
    catch e
      Articles.update _id: articleId,
        $set:
          enhancements:
            error: "" + e
      throw e

  retrieveProMedArticle: (articleId) ->
    @unblock()
    article = PromedPosts.findOne
      promedId: articleId

    if article
      promedDate: article.promedDate
      url: "http://www.promedmail.org/post/#{article.promedId}"
      subject: article.subject.raw

  queryForSuggestedArticles: (eventId) ->
    @unblock()
    check eventId, Match.Maybe(String)
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
    Articles.find(userEventIds: eventId).forEach (relatedEventSource) ->
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
  SetBSVEAuthTicketPassword: (authInfo) ->
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

export autogenerateDocumentIncidents = autogenerateDocumentIncidents
