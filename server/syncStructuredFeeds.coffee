import Incidents from '/imports/collections/incidentReports'
import AutoEvents from '/imports/collections/autoEvents'
import Feeds from '/imports/collections/feeds'
import {capitalize} from '/imports/utils'
import Constants from '/imports/constants.coffee'

module.exports = ->
  nameToGeoname = {}
  getGeonames = (countryNames) ->
    countryNames.forEach (country) ->
      if not nameToGeoname[country]
        geonamesResult = HTTP.get Constants.GRITS_URL + '/api/geoname_lookup/api/lookup',
          params:
            q: country
        nameToGeoname[country] = geonamesResult.data.hits[0]._source
        delete nameToGeoname[country].alternateNames

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
    resp = HTTP.get(WHOCholeraDataUrl, {})
    getGeonames(resp.data.fact.map (fact)-> fact.dim.COUNTRY)
    Incidents.remove(sourceFeed: feedId)
    resp.data.fact.forEach (fact) ->
      Incidents.insert
        sourceFeed: feedId
        constraining: true
        dateRange:
          type: "precise"
          start: new Date(fact.dim.YEAR + "")
          end: new Date(parseInt(fact.dim.YEAR) + 1 + "")
        locations: [nameToGeoname[fact.dim.COUNTRY]]
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
    resp = HTTP.get(WHOTBDataUrl, {})
    getGeonames(resp.data.fact.map (fact)-> fact.dim.COUNTRY)
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
          locations: [nameToGeoname[fact.dim.COUNTRY]]
          cases: parseInt(maxValue)
          resolvedDisease:
            id: "http://purl.obolibrary.org/obo/DOID_399"
            text: "Tuberculosis"
          species:
            id: "tsn:180092"
            text: "Homo sapiens"
          addedDate: new Date()

  # Import CDC data
  CDCDataURLs = [
    url: "https://data.cdc.gov/resource/w3an-exa3.json"
    title: "NNDSS Meningococcal disease to Pertussis"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_0080176"
      text: "Meningococcal Meningitis"
      valProp: "meningococcal_disease_all_serogroups_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_1116"
      text: "pertussis"
      valProp: "pertussis_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_10264"
      text: "Mumps"
      valProp: "mumps_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/yi9b-zyiu.json"
    title: "NNDSS Legionellosis to Malaria"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_10458"
      text: "Legionellosis"
      valProp: "legionellosis_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_12365"
      text: "Malaria"
      valProp: "malaria_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/f5br-wfa6.json"
    title: "NNDSS Invasive pneumococcal diseases (all ages)"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_552"
      text: "Pneumonia"
      valProp: "invasive_pneumococcal_disease_all_ages_confirmed_current_week"
    ]
  ]
  CDCDataURLs.forEach (CDCItem)->
    feed = Feeds.findOne(url: CDCItem.url)
    if true or not (feed and moment().isBefore(moment(feed.addedDate).add(7, 'days')))
      Feeds.upsert({
        url: CDCItem.url
      }, {
        $set:
          title: CDCItem.title
          addedDate: new Date()
          structuredData: true
      })
      feedId = Feeds.findOne(url: CDCItem.url)._id
      resp = HTTP.get(CDCItem.url, {})
      getGeonames(resp.data.map (d)-> d.reporting_area)
      Incidents.remove(sourceFeed: feedId)
      resp.data.forEach (dataItem)->
        {
          mmwr_week,
          mmwr_year,
          reporting_area
        } = dataItem
        mmwr_week = parseInt(mmwr_week)
        mmwr_year = parseInt(mmwr_year)
        startDate = moment("#{mmwr_year}-01-01").add((parseInt(mmwr_week) - 1) * 7, 'days').toDate()
        endDate = moment(startDate).add(7, 'days').toDate()
        CDCItem.diseases.forEach (disease)->
          value = parseInt(dataItem[disease.valProp])
          location = nameToGeoname[reporting_area]
          if value.toString() != "NaN" and location.featureCode == "ADM1" and location.countryCode == "US"
            Incidents.insert
              sourceFeed: feedId
              constraining: true
              dateRange:
                type: "precise"
                start: startDate
                end: endDate
              locations: [location]
              cases: value
              resolvedDisease:
                id: disease.id
                text: disease.text
              species:
                id: "tsn:180092"
                text: "Homo sapiens"
              addedDate: new Date()

  console.log "Constraining incidents updated"
