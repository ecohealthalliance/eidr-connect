import Articles from '/imports/collections/articles.coffee'
import { forEachAsync } from '/imports/utils'

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
    ,
      'enhancements.diagnoserVersion': $lt: '0.4.4'
      title: /\bMERS\b/
    ],
    reviewed: $in: [null, false]
  }, {
    limit: 20
    sort:
      addedDate: -1
  }).fetch()
  forEachAsync(batch, (article, next, done) ->
    count++
    Meteor.call('getArticleEnhancementsAndUpdate', article._id, {
      hideLogs: true
      priority: false
      reprocess: true
    }, (error)->
      if error
        console.log article
        console.log error
        done()
      else
        next()
    )
  , ->
    console.log "processed #{count} articles"
    busyProcessing = false
  )
