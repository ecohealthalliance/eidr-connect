import Geonames from '/imports/collections/geonames'

Meteor.methods
  addGeoname: (geoname)->
    if not Roles.userIsInRole(@userId, ['admin', 'curator'])
      throw new Meteor.Error("auth", "Insufficient permissions.")
    Geonames.insert(geoname)
