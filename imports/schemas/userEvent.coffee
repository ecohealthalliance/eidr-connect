userEventSchema = new SimpleSchema
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
  disease:
    type: String
    optional: true
  eventName:
    type: String
  lastIncidentDate:
    type: Date
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
  displayOnPromed:
    type: Boolean
    optional: true
  incidents:
    type: [Object]
    optional: true
  'incidents.id':
    type: String
  'incidents.associationDate':
    type: Date
  'incidents.associationUserId':
    type: String

module.exports = userEventSchema
