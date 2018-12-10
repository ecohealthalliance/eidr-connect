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
    optional: true
  # The timezone used to specify the publishDate in the document.
  publishDateTZ:
    type: String
    optional: true
  title:
    type: String
    optional: true
  url:
    type: String
    optional: true
  content:
    type: String
    optional: true
  userEventIds:
    type: [String]
    optional: true
  reviewed:
    type: Boolean
    optional: true
  reviewedDate:
    type: Date
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
