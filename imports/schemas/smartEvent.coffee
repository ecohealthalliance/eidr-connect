import GeonameSchema from '/imports/schemas/geoname.coffee'

smartEventSchema = new SimpleSchema
  _id:
    type: String
    optional: true
  createdByUserId:
    type: String
    optional: true
  createdByUserName:
    type: String
    optional: true
  creationDate:
    type: Date
    optional: true
  eventName:
    type: String
  diseases:
    type: [Object]
    optional: true
  "diseases.$.id":
    type: String
    optional: true
  "diseases.$.text":
    type: String
    optional: true
  lastModifiedByUserId:
    type: String
    optional: true
  lastModifiedByUserName:
    type: String
    optional: true
  lastModifiedDate:
    type: Date
    optional: true
  summary:
    type: String
  deleted:
    type: Boolean
    optional: true
  deletedDate:
    type: Date
    optional: true
  dateRange:
    type: Object
    optional: true
  "dateRange.start":
    type: Date
  "dateRange.end":
    type: Date
  locations:
    type: [GeonameSchema]
    optional: true

module.exports = smartEventSchema
