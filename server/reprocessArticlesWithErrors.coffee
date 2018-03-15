import Articles from '/imports/collections/articles.coffee'
import { forEachAsync } from '/imports/utils'

module.exports = ->
  successes = 0
  batch = Articles.find({
    'enhancements.error':
      $exists: true
  }, {
    limit: 200
    sort:
      addedDate: -1
  }).fetch()
  forEachAsync(batch, (article, next, done) ->
    Meteor.call('getArticleEnhancementsAndUpdate', article._id, {
      hideLogs: true
      priority: false
      reprocess: true
    }, (error)->
      if error
        console.log article
        console.log error
      else
        successes++
      console.log "#{successes} / #{batch.length} airticles with errors successfully processed"
      next()
    )
  , ->
    console.log "Done"
  )
