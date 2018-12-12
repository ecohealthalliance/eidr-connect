import GeonameSchema from '/imports/schemas/geoname.coffee'

AnnotationSchema = new SimpleSchema
  "text":
    type: String
    optional: true
  "textOffsets":
    type: [Number]
    optional: true

IncidentReportSchema = new SimpleSchema
  _id:
    type: String
    optional: true
  type:
    type: String
    optional: true
    allowedValues: [
      'caseCount'
      'deathCount'
      'cumulativeCaseCount'
      'cumulativeDeathCount'
      'activeCount'
      'specify'
    ]
  articleId:
    type: String
    optional: true
  addedByUserName:
    type: String
    optional: true
  addedByUserId:
    type: String
    optional: true
  modifiedByUserName:
    type: String
    optional: true
  modifiedByUserId:
    type: String
    optional: true
  modifiedDate:
    type: Date
    optional: true
  addedDate:
    type: Date
    optional: true
  cases:
    type: Number
    optional: true
  deaths:
    type: Number
    optional: true
  specify:
    type: String
    optional: true
  locations:
    type: [GeonameSchema]
    optional: true
  dateRange:
    type: Object
    optional: true
  "dateRange.type":
    type: String
    allowedValues: ["day","precise"]
    optional: true
  # Datetimes are treated as offset naive so the look the same from any
  # browser client and match the dates in their source documents.
  "dateRange.start":
    type: Date
    optional: true
  "dateRange.end":
    type: Date
    optional: true
  # Cumulative counts have an undefined/implicit start date.
  # They are running totals since the last cumulative count for the area and event.
  # Cumulative counts are exhaustive counts that capture all the cases for the
  # date range and location, but exhaustive counts are not necessarily cumulative.
  "dateRange.cumulative":
    type: Boolean
    optional: true
  travelRelated:
    type: Boolean
    optional: true
  approximate:
    type: Boolean
    optional: true
  min:
    type: Boolean
    optional: true
  max:
    type: Boolean
    optional: true
  # Deprecated
  disease:
    type: String
    optional: true
  resolvedDisease:
    type: Object
    optional: true
  "resolvedDisease.id":
    type: String
    optional: true
  "resolvedDisease.text":
    type: String
    optional: true
  species:
    type: Object
    optional: true
  "species.id":
    type: String
    optional: true
  "species.text":
    type: String
    optional: true
  status:
    type: String
    optional: true
  deleted:
    type: Boolean
    optional: true
  deletedDate:
    type: Date
    optional: true
  # Unaccepted incidents are hidden from the UI except for in the incident
  # extraction view. This property is used to annotate counts which do not
  # appear to be case couse so the user can check them for false negatives.
  accepted:
    type: Boolean
    optional: true
  annotations:
    type: Object
    optional: true
  "annotations.case":
    type: [AnnotationSchema]
    optional: true
  "annotations.date":
    type: [AnnotationSchema]
    optional: true
  "annotations.location":
    type: [AnnotationSchema]
    optional: true
  "annotations.disease":
    type: [AnnotationSchema]
    optional: true
  autogenerated:
    type: Boolean
    optional: true
  # deprecated
  url:
    type: String
    optional: true
  # Url of the feed the incident was derived from.
  sourceFeed:
    type: String
    optional: true
  constraining:
    type: Boolean
    optional: true

module.exports = IncidentReportSchema
