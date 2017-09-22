import Articles from '/imports/collections/articles.coffee'

busyProcessing = false
module.exports = ->
  if busyProcessing
    return
  else
    busyProcessing = true
  count = 0
  batch = Articles.find({
    $or: [
      enhancements: $exists: false
    ,
      'enhancements.diagnoserVersion': $lt: '0.4.2'
    ]
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
    Meteor.call('getArticleEnhancementsAndUpdate', article._id, {
      hideLogs: true
      priority: false
      reprocess: true
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
