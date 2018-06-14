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

  # Import CDC NNDSS data
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
  ,
    url: "https://data.cdc.gov/resource/e8px-pinp.json"
    title: "NNDSS Spotted fever rickettsiosis to Syphilis, primary and secondary"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_11104"
      text: "Spotted Fever"
      valProp: "spotted_fever_rickettsiosis_probable_current_week_flag"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_4166"
      text: "Syphilis"
      valProp: "syphilis_primary_and_secondary_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/fbj9-ad6e.json"
    title: "NNDSS Cryptosporidiosis to Dengue virus infection"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_1733"
      text: "Cryptosporidiosis"
      valProp: "cryptosporidiosis_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_12205"
      text: "Dengue"
      valProp: "dengue_virus_infections_dengue_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/dsz3-9wvn.json"
    title: "NNDSS Chlamydia trachomatis infection to Coccidioidomycosis"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_11263"
      text: "Chlamydia"
      valProp: "chlamydia_trachomatis_infection_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_13450"
      text: "Coccidioidomycosis"
      valProp: "coccidioidomycosis_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/r64k-cjis.json"
    title: "NNDSS Giardiasis to Haemophilus influenza"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_10718"
      text: "Giardiasis"
      valProp: "giardiasis_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_7551"
      text: "Gonorrhea"
      valProp: "gonorrhea_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_0080179"
      text: "Haemophilus Meningitis"
      valProp: "haemophilus_influenzae_invasive_disease_all_ages_all_serotypes_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/nvth-8i2n.json"
    title: "NNDSS Hepatitis (viral, acute, by type) C"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_1883"
      text: "hepatitis C"
      valProp: "hepatitis_viral_acute_by_type_c_confirmed_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/xy2s-u2bh.json"
    title: "NNDSS - Table II. Hepatitis (viral, acute, by type) A & B"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_12549"
      text: "hepatitis A"
      valProp: "hepatitis_viral_acute_by_type_a_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_2043"
      text: "hepatitis B"
      valProp: "hepatitis_viral_acute_by_type_b_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/f5br-wfa6.json"
    title: "NNDSS Invasive pneumococcal disease, all ages"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_874"
      text: "Bacterial pneumonia"
      valProp: "invasive_pneumococcal_disease_all_ages_confirmed_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/n3ub-5wxs.json"
    title: "NNDSS Tetanus to Varicella"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_8659"
      text: "Chickenpox"
      valProp: "varicella_chickenpox_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_11338"
      text: "Tetanus"
      valProp: "tetanus_current_week"
    ]
  ,
    url: "https://data.cdc.gov/resource/rcpn-dfmg.json"
    title: "NNDSS West Nile to Zika"
    diseases: [
      id: "http://purl.obolibrary.org/obo/DOID_060478"
      text: "Zika Fever"
      valProp: "zika_virus_disease_non_congenital_current_week"
    ,
      id: "http://purl.obolibrary.org/obo/DOID_2366"
      text: "West Nile Fever"
      valProp: "west_nile_virus_disease_nonneuroinvasive_current_week"
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
        if "NaN" in [mmwr_year.toString(), mmwr_week.toString()]
          return
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
