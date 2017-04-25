UserEvents = require '/imports/collections/userEvents.coffee'
incidentReportSchema = require '/imports/schemas/incidentReport.coffee'
Incidents = require '/imports/collections/incidentReports.coffee'
articleSchema = require '/imports/schemas/article.coffee'
Articles = require '/imports/collections/articles.coffee'
PromedPosts = require '/imports/collections/promedPosts.coffee'
CuratorSources = require '/imports/collections/curatorSources'
Feeds = require '/imports/collections/feeds'
feedSchema = require '/imports/schemas/feed'
Constants = require '/imports/constants.coffee'

autoprocessArticles = ->
  count = 0
  Articles.find({
    enhancements: $exists: false
  }, {
    limit: 10
    sort:
      addedDate: -1
  }).forEach (article) ->
    count++
    try
      Meteor.call('getArticleEnhancementsAndUpdate', article, {
        hideLogs: true
        priority: false
      })
    catch e
      console.log article
      console.log e
  console.log "processed #{count} articles"
  if count == 0
    # wait 100 seconds
    Meteor.setTimeout(autoprocessArticles, 100000)
  else
    autoprocessArticles()

Meteor.startup ->
  Meteor.setTimeout(autoprocessArticles, 0)
    