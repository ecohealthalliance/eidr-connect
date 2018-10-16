module.exports = new SimpleSchema
  "admin1Name":
    type: String
    optional: true
  "admin2Name":
    type: String
    optional: true
  "admin1Code":
    type: String
    optional: true
  "admin2Code":
    type: String
    optional: true
  "admin3Code":
    type: String
    optional: true
  "admin4Code":
    type: String
    optional: true
  "alternateNames":
    type: [String]
    optional: true
  "countryName":
    type: String
    optional: true
  "countryCode":
    type: String
    optional: true
  "featureClass":
    type: String
    optional: true
  "featureCode":
    type: String
    optional: true
  "id":
    type: String
  "latitude":
    type: Number
    decimal: true
  "longitude":
    type: Number
    decimal: true
  "name":
    type: String
  "population":
    type: Number
    optional: true
  # TODO: Remove these properties.
  "asciiName":
    type: String
    optional: true
  "rawNames":
    type: [String]
    optional: true
  "cc2":
    type: String
    optional: true
  "elevation":
    type: String
    optional: true
  "dem":
    type: String
    optional: true
  "timezone":
    type: String
    optional: true
  "modificationDate":
    type: String
    optional: true
