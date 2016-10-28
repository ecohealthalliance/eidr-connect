###
#  ensures that an index is created on a collection
#
# @param {object} collection, a meteor collection to apply the index
# @param {object} keys, the index fields
# @param {object} options, this index options
# @see https://docs.mongodb.com/v3.2/reference/method/db.collection.createIndex/
###
export ensureIndexes = (collection, keys, options) ->
  options = options || {}
  collection.rawCollection().createIndex keys, options, (error) ->
    if error
      console.error "[#{collection._name} ensureIndexes]: ", error

###
# ObjectIdNotSupportedError - error thrown when a bulk update is performed with
#   any Mongo ObjectID's, which are not supported.
#
# @param {string} [message], (optional) the message to the user
###
class ObjectIdNotSupportedError extends Error
  name: 'ObjectIdNotSupportedError'
  constructor: (message) ->
    @message = message || 'Bulk Update does not support Mongo ObjectID.'
    super()

###
# bulkUpdate - updates an array of documents at once
#
# @param {object} collection, a meteor collection to apply the updates
# @param {object[]} updates, array containing positional values for the update
# @param {object} updates[0], the string _id of the document
# @param {object} updates[1], the fields to update with appropriate mongodb operator
#   ex: `['iPKcdkR4ozb5ResKE', {$set: {url: 'some/place'}}]`
# @param {function} callback, the method to execute when done
#
# @throws {ObjectIdNotSupported}
# @note this method does not support ObjectIds inside a Meteor environment
###
export bulkUpdate = (collection, updates, callback) ->
  if updates.length <= 0
    return
  # get the bulk operation interface
  bulk = collection.rawCollection().initializeUnorderedBulkOp()
  updates.forEach (update) ->
    # not supported on mongodb ObjectId
    if typeof update[0] == 'object'
      throw new ObjectIdNotSupportedError()
    bulk.find({_id: update[0]}).updateOne(update[1])
  # execute all operations on mongodb at once
  if typeof callback == 'function'
    bulk.execute(callback)
  else
    bulk.execute()

###
# attemptBulkUpdate - implementation of bulkUpdate that falls back to single document
#   update if it throws an ObjectIdNotSupported exception, outputs to console.info
#
# @param {object} collection, a meteor collection to apply the updates
# @param {object[]} updates, array containing positional values for the update
# @param {object} updates[0], the string _id of the document
# @param {object} updates[1], the fields to update with appropriate mongodb operator
#   ex: `['iPKcdkR4ozb5ResKE', {$set: {url: 'some/place'}}]`
###
export attemptBulkUpdate = (collection, updates) ->
  try
    bulkUpdate(collection, updates, (err, res) ->
      if err
        console.error "[#{collection._name} bulkUpdate] error: ", error
        return
      console.info "[#{collection._name} bulkUpdate] nInserted: #{res.nInserted}"
      console.info "[#{collection._name} bulkUpdate] nUpserted: #{res.nUpserted}"
      console.info "[#{collection._name} bulkUpdate] nMatched : #{res.nMatched}"
      console.info "[#{collection._name} bulkUpdate] nModified: #{res.nModified}"
      console.info "[#{collection._name} bulkUpdate] nRemoved : #{res.nRemoved}"
    )
  catch e
    if e instanceof ObjectIdNotSupportedError
      console.warn e.message
      console.warn 'Falling back to individual updates'
      # perform individual updates
      count = 0
      updates.forEach (u) ->
        collection.update({_id: u[0]}, u[1])
        count++
      console.info "[#{collection._name}] updated: #{count}"
    else
      # rethrow the unknow error
      throw e
