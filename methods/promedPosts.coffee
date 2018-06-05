if Meteor.isServer
  PromedPosts = require '/imports/collections/promedPosts.coffee'
  Articles = require '/imports/collections/articles.coffee'
  Feeds = require '/imports/collections/feeds.coffee'

  Meteor.methods
    fetchPromedPosts: (range) ->
      @unblock
      endDate = range?.endDate || new Date()
      startDate = moment(endDate).subtract(2, 'weeks').toDate()
      if range?.startDate
        startDate = range.startDate
      query =
        promedDate:
          $gte: new Date(startDate)
          $lte: new Date(endDate)

      posts = PromedPosts.find(query, {
        fields:
          feedId: 1
          promedId: 1
          subject: 1
          content: 1
          promedDate: 1
          articles: 1
          links: 1
      }).fetch()
      recordNewPosts(posts)

  recordNewPosts = (posts) ->
    for post in posts
      feedId = Feeds.findOne(promedId: post.feedId)?._id
      if feedId
        # Normalize post for display/subscription
        normalizedPost =
          url: "promedmail.org/post/#{post.promedId}"
          addedDate: new Date()
          publishDate: post.promedDate
          publishDateTZ: "EDT"
          title: post.subject.raw
          reviewed: false
          feedId: feedId
        Articles.upsert({_id: post._id._str}, {$setOnInsert: normalizedPost})
