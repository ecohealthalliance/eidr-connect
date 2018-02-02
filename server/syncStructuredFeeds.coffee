import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'
import {capitalize} from '/imports/utils'
import Constants from '/imports/constants.coffee'

module.exports = ->
  # Import Cholera data
  WHOCholeraDataUrl = "http://apps.who.int/gho/athena/data/GHO/CHOLERA_0000000001.json?profile=simple&filter=COUNTRY:*;REGION:*"
  HTTP.get WHOCholeraDataUrl, (err, resp)->
    countryToGeoname = {}
    resp.data.fact.forEach (fact) ->
      country = fact.dim.COUNTRY
      if not countryToGeoname[country]
        geonamesResult = HTTP.get Constants.GRITS_URL + '/api/geoname_lookup/api/lookup',
          params:
            q: country
        countryToGeoname[country] = geonamesResult.data.hits[0]._source
    Incidents.remove(url: WHOCholeraDataUrl)
    resp.data.fact.forEach (fact) ->
      Incidents.insert
        url: WHOCholeraDataUrl
        dateRange:
          cumulative: true
          type: "precise"
          start: new Date(fact.dim.YEAR)
          end: new Date(parseInt(fact.dim.YEAR) + 1)
        locations: [countryToGeoname[fact.dim.COUNTRY]]
        cases: parseInt(fact.Value)
        resolvedDisease:
          text: 'Cholera'
          id: 'http://purl.obolibrary.org/obo/DOID_1498'
        species:
          id: "tsn:180092"
          text: "Homo sapiens"
        addedDate: new Date()
