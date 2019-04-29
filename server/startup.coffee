import incidentReportSchema from '/imports/schemas/incidentReport'
import Incidents from '/imports/collections/incidentReports'
import Articles from '/imports/collections/articles'
import autoprocessArticles from '/server/autoprocess'
import reprocessArticlesWithErrors from '/server/reprocessArticlesWithErrors'
import updateDatabase from '/server/updaters'
import syncCollection from '/server/oneWaySync'
import syncStructuredFeeds from '/server/syncStructuredFeeds'
import updateAutoEvents from '/server/updateAutoEvents'
import Feeds from '/imports/collections/feeds'
import feedSchema from '/imports/schemas/feed'
import cheerio from 'cheerio'

Meteor.startup ->
  # Clean-up curatorInboxSourceId when user goes offline
  Meteor.users.find({'status.online': true}).observe
    removed: (user) ->
      Meteor.users.update(user._id, {$set : {'status.curatorInboxSourceId': null}})

  # Ensure promed feed exists
  promedFeed = Feeds.findOne(url: 'promedmail.org/post/')
  if not promedFeed?.promedId
    newFeedProps =
      title: 'ProMED-mail'
      url: 'promedmail.org/post/'
      promedId: '1'
    feedSchema.validate(newFeedProps)
    Feeds.upsert promedFeed?._id,
      $set: newFeedProps
      $setOnInsert:
        addedDate: new Date()

  # Ensure feeds for foreign language promed feeds exist
  [
    url: 'promedmail.org/es'
    promedId: '7'
    title: 'ProMED-mail Español'
  ,
    url: 'promedmail.org/ru'
    promedId: '12'
    title: 'ProMED-mail Русский (Russian)'
  ,
    url: 'promedmail.org/mbds'
    promedId: '15'
    title: 'ProMED-mail Mekong Basin'
  ,
    url: 'promedmail.org/fr'
    promedId: '18'
    title: 'ProMED-mail Afrique Francophone'
  ,
    url: 'promedmail.org/eafr'
    promedId: '24'
    title: 'ProMED-mail Anglophone Africa'
  ,
    url: 'promedmail.org/pt'
    promedId: '26'
    title: 'ProMED-mail Português'
  ,
    url: 'promedmail.org/soas'
    promedId: '170'
    title: 'ProMED-mail South Asia'
  ,
    url: 'promedmail.org/mena'
    promedId: '171'
    title: 'ProMED-mail Middle East/North Africa'
  ].forEach (newFeedProps)->
    promedFeed = Feeds.findOne(url: newFeedProps.url)
    if not promedFeed?.title
      feedSchema.validate(newFeedProps)
      Feeds.upsert promedFeed?._id,
        $set: newFeedProps
        $setOnInsert:
          addedDate: new Date()

  # Add rss feeds
  Feeds.upsert({
    url: "https://ecdc.europa.eu/en/taxonomy/term/1307/feed"
  }, {
    $set:
      #url: "https://ecdc.europa.eu/en/taxonomy/term/1307/feed"
      rss: true
      title: 'ECDC - RSS - news'
  })

  updateDatabase()

  # Validate incidents
  if Meteor.isDevelopment
    console.log "starting incident validation"
    incidentOffset = 0
    validateIncidents = ->
      noMoreIncidents = true
      Incidents.find({
        deleted: {$in: [null, false]}
      }, {
        skip: incidentOffset
        limit: 100
      }).forEach (incident)->
        incidentOffset++
        noMoreIncidents = false
        try
          incidentReportSchema.validate(incident)
        catch error
          console.log error
          console.log JSON.stringify(incident, 0, 2)
      if noMoreIncidents
        console.log "incidents validated"
        Meteor.clearInterval(interval)
    interval = Meteor.setInterval(validateIncidents, 20000)

  # If a remote EIDR-C instance url is provided, periodically pull data from it.
  if process.env.ONE_WAY_SYNC_URL
    # Do initial sync on startup
    Meteor.setTimeout(syncCollection, 1000)
    # Pull data every 6 hours
    Meteor.setInterval(syncCollection, 6 * 60 * 60 * 1000)

  Meteor.setInterval updateAutoEvents, 60 * 60 * 1000
  updateAutoEvents()

  if not Meteor.isAppTest and not Meteor.isDevelopment
    reprocessArticlesWithErrors()
    Meteor.setInterval(autoprocessArticles, 100000)

    Meteor.setInterval ->
      # Pull in the latest ProMED posts for processing.
      Meteor.call('fetchPromedPosts',
        startDate: moment().subtract(2, 'days').toDate()
        endDate: new Date()
      )

      feeds = Feeds.find(rss: true).fetch()
      for feed in feeds
        console.log "Reading feed: " + feed.url
        response = HTTP.get(feed.url)
        $xml = cheerio.load(response.content, xml: xml: true)
        rssItems = Array.from($xml('item').map (idx)->
          $item = $xml('item').eq(idx)
          {
            title: $item.find('title').text()
            link: $item.find('link').text()
            pubDate: $item.find('pubDate').text()
          }
        )
        rssItems.forEach (item) ->
          if not Articles.findOne(url: item.link)
            # Normalize post for display/subscription
            normalizedPost =
              url: item.link
              addedDate: new Date()
              publishDate: new Date(item.pubDate)
              publishDateTZ: "UTC"
              title: item.title
              reviewed: false
              feedId: feed._id
            console.log "Adding post: " + item.link
            Articles.insert(normalizedPost)
    , 5 * 60 * 60 * 1000

    console.log "Syncing structured data feeds"
    syncStructuredFeeds()
