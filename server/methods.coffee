UserEvents = require '/imports/collections/userEvents.coffee'
Articles = require '/imports/collections/articles.coffee'
PromedPosts = require '/imports/collections/promedPosts.coffee'
Constants = require '/imports/constants.coffee'
import { formatUrl } from '/imports/utils.coffee'

DateRegEx = /<span class="blue">Published Date:<\/span> ([^<]+)/

Meteor.methods
  getArticleEnhancements: (article) ->
    @unblock()
    check article.url, Match.Maybe(String)
    check article.content, Match.Maybe(String)
    check article.publishDate, Match.Maybe(Date)
    check article.addedDate, Match.Maybe(Date)
    geonameIds = []
    console.log "Calling GRITS API @ " + Constants.GRITS_URL
    params =
      api_key: "Cr9LPAtL"
      returnSourceContent: true
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
    return result.data

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
    # Collect related event source ID's
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
