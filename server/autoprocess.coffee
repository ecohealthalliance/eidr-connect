Articles = require '/imports/collections/articles.coffee'

busyProcessing = false
autoprocessArticles = ->
  if busyProcessing
    return
  else
    busyProcessing = true
  count = 0
  Articles.find({
    enhancements: $exists: false
  }, {
    limit: 20
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
  busyProcessing = false

Meteor.startup ->
  if not Meteor.isAppTest
    Meteor.setInterval(autoprocessArticles, 100000)
