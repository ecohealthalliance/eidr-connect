Articles = require '/imports/collections/articles.coffee'

busyProcessing = false
autoprocessArticles = ->
  if busyProcessing
    return
  else
    busyProcessing = true
  count = 0
  batch = Articles.find({
    enhancements: $exists: false
  }, {
    limit: 20
    sort:
      addedDate: -1
  }).fetch()
  forEachAsync = (list, func, done)->
    if list.length > 0
      func(list[0], (error)->
        if error
          done()
        else
          forEachAsync(list.slice(1), func, done)
      )
    else
      done()
  forEachAsync(batch, (article, next) ->
    count++
    Meteor.call('getArticleEnhancementsAndUpdate', article, {
      hideLogs: true
      priority: false
    }, (error)->
      if error
        console.log article
        console.log error
        next(error)
      else
        next()
    )
  , ->
    console.log "processed #{count} articles"
    busyProcessing = false
  )

Meteor.startup ->
  if not Meteor.isAppTest
    Meteor.setInterval(autoprocessArticles, 100000)
