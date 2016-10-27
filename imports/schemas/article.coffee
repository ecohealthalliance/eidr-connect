articleSchema = new SimpleSchema(
  _id:
    type: String
    optional: true
  addedByUserId:
    type: String
  addedByUserName:
    type: String
  addedDate:
    type: Date
  publishDate:
    type: Date
  # The timezone used to specify the publishDate in the article.
  publishDateTZ:
    type: String
  title:
    type: String
  url:
    type: String
  userEventId:
    type: String
  reviewed:
    type: Boolean
    optional: true
)
module.exports = articleSchema
