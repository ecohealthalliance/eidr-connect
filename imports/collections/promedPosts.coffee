if Meteor.isServer
  PromedPosts = null
  try
    spaDb = new MongoInternals.RemoteCollectionDriver(process.env.SPA_MONGO_URL)
    PromedPosts = new Meteor.Collection("posts", { _driver: spaDb })
    PromedPosts.rawCollection().createIndex({promedDate: 1})
  catch e
    console.warn 'Unable to connect to remote SPA mongodb.'

  module.exports = PromedPosts