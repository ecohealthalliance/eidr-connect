import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'
import Feeds from '/imports/collections/feeds'
import {capitalize} from '/imports/utils'
import Constants from '/imports/constants.coffee'

module.exports = ->
  countryToGeoname = {}
  getCountryGeonames = (facts) ->
    facts.forEach (fact) ->
      country = fact.dim.COUNTRY
      console.log country
      if not countryToGeoname[country]
        geonamesResult = HTTP.get Constants.GRITS_URL + '/api/geoname_lookup/api/lookup',
          params:
            q: country
        countryToGeoname[country] = geonamesResult.data.hits[0]._source
        delete countryToGeoname[country].alternateNames

  # Import Cholera data
  WHOCholeraDataUrl = "http://apps.who.int/gho/athena/data/GHO/CHOLERA_0000000001.json?profile=simple&filter=COUNTRY:*;REGION:*"
  feed = Feeds.findOne(url: WHOCholeraDataUrl)
  if not (feed and moment().isBefore(moment(feed.addedDate).add(20, 'days')))
    # Only reimport the data if it hasn't been updated in at least 20 days
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
      getCountryGeonames(resp.data.fact)
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

  # Import TB data
  WHOTBDataUrl = "http://apps.who.int/gho/athena/data/GHO/MDG_0000000020,TB_e_inc_num,TB_e_inc_tbhiv_100k,TB_e_inc_tbhiv_num.json?profile=simple&filter=COUNTRY:*;REGION:*"
  feed = Feeds.findOne(url: WHOTBDataUrl)
  if not (feed and moment().isBefore(moment(feed.addedDate).add(20, 'days')))
    Feeds.upsert({
      url: WHOTBDataUrl
    }, {
      $set:
        title: "WHO Annual TB Cases by Country"
        addedDate: new Date()
        structuredData: true
    })
    feedId = Feeds.findOne(url: WHOTBDataUrl)._id
    HTTP.get WHOTBDataUrl, {}, (err, resp)->
      if err
        return console.log(err)
      getCountryGeonames(resp.data.fact)
      Incidents.remove(sourceFeed: feedId)
      resp.data.fact.forEach (fact) ->
        if fact.dim.GHO == "Number of incident tuberculosis cases"
          parsedValue = /(\d+) \[(\d+)\-(\d+)\]/.exec(fact.Value)
          maxValue = parsedValue[3]
          Incidents.insert
            sourceFeed: feedId
            constraining: true
            dateRange:
              type: "precise"
              start: new Date(fact.dim.YEAR + "")
              end: new Date(parseInt(fact.dim.YEAR) + 1 + "")
            locations: [countryToGeoname[fact.dim.COUNTRY]]
            cases: parseInt(maxValue)
            resolvedDisease:
              id: "http://purl.obolibrary.org/obo/DOID_399"
              text: "Tuberculosis"
            species:
              id: "tsn:180092"
              text: "Homo sapiens"
            addedDate: new Date()

    console.log "Constraining incidents updated"
