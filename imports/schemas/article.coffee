articleSchema = new SimpleSchema
  _id:
    type: String
    optional: true
  addedByUserId:
    type: String
    optional: true
  addedByUserName:
    type: String
    optional: true
  addedDate:
    type: Date
  publishDate:
    type: Date
  # The timezone used to specify the publishDate in the document.
  publishDateTZ:
    type: String
  title:
    type: String
  url:
    type: String
    optional: true
  content:
    type: String
    optional: true
  userEventId:
    type: String
    optional: true
  reviewed:
    type: Boolean
    optional: true
  enhancements:
    type: Object
    optional: true
  deleted:
    type: Boolean
    optional: true
  deletedDate:
    type: Date
    optional: true
  feedId:
    type: String
    optional: true

module.exports = articleSchema
