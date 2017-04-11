feedSchema = new SimpleSchema
  _id:
    type: String
    optional: true
  title:
    type: String
    optional: true
  url:
    type: String
    optional: true
  addedByUserId:
    type: String
    optional: true
  addedDate:
    type: Date

module.exports = feedSchema
