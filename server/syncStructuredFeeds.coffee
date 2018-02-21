import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'
import Feeds from '/imports/collections/feeds'
import {capitalize} from '/imports/utils'
import Constants from '/imports/constants.coffee'

module.exports = ->
  # Import Cholera data
  WHOCholeraDataUrl = "http://apps.who.int/gho/athena/data/GHO/CHOLERA_0000000001.json?profile=simple&filter=COUNTRY:*;REGION:*"
  feed = Feeds.findOne(url: WHOCholeraDataUrl)
  if feed
    if moment().isBefore(moment(feed.addedDate).add(20, 'days'))
      # Only reimport the data if it hasn't been updated in at least 20 days
      return
  Feeds.upsert({
    url: WHOCholeraDataUrl
  }, {
    $set:
      title: "WHO Annual Cholera Cases by Country"
      addedDate: new Date()
      structuredData: true
  })
  feedId = Feeds.findOne(url: WHOCholeraDataUrl)._id
  HTTP.get WHOCholeraDataUrl, {}, (err, resp)->
    if err
      return console.log(err)
    countryToGeoname = {}
    resp.data.fact.forEach (fact) ->
      country = fact.dim.COUNTRY
      console.log country
      if not countryToGeoname[country]
        geonamesResult = HTTP.get Constants.GRITS_URL + '/api/geoname_lookup/api/lookup',
          params:
            q: country
        countryToGeoname[country] = geonamesResult.data.hits[0]._source
        delete countryToGeoname[country].alternateNames
    Incidents.remove(sourceFeed: feedId)
    resp.data.fact.forEach (fact) ->
      Incidents.insert
        sourceFeed: feedId
        constraining: true
        dateRange:
          type: "precise"
          start: new Date(fact.dim.YEAR + "")
          end: new Date(parseInt(fact.dim.YEAR) + 1 + "")
        locations: [countryToGeoname[fact.dim.COUNTRY]]
        cases: parseInt(fact.Value)
        resolvedDisease:
          id: "http://purl.obolibrary.org/obo/DOID_1498"
          text: "Cholera"
        species:
          id: "tsn:180092"
          text: "Homo sapiens"
        addedDate: new Date()
    console.log "Constraining incidents updated"
