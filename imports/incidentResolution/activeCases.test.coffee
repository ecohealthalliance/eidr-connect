import { chai } from 'meteor/practicalmeteor:chai'
import incidents from './incidents'
import convertAllIncidentsToDifferentials from './convertAllIncidentsToDifferentials'
import {
  differentialIncidentsToSubIntervals,
  subIntervalsToLP,
  intervalToEndpoints,
  removeOutlierIncidents,
  createSupplementalIncidents,
  extendSubIntervalsWithValues,
  dailyRatesToActiveCases,
  subIntervalsToDailyRates,
  enumerateDateRange,
  mapLocationsToMaxSubIntervals
} from './incidentResolution'
import LocationTree from './LocationTree.coffee'

lome =
  admin1Name: "Maritime"
  countryName: "Togolese Republic"
  featureClass: "P"
  featureCode: "PPLC"
  id: "2365267"
  name: "Lomé"

tongo =
  countryName: "Togolese Republic"
  featureClass: "A"
  featureCode: "PCLI"
  id: "2363686"
  name: "Togolese Republic"

overlappingIncidents = [{
  cases: 40
  dateRange:
    start: new Date("Dec 31 2010 UTC")
    end: new Date("Jan 5 2011 UTC")
  locations: [lome]
}, {
  cases: 10
  dateRange:
    start: new Date("Jan 3 2011 UTC")
    end: new Date("Jan 7 2011 UTC")
  locations: [lome]
}]


describe 'Active Case Utils', ->

  it 'can enumerate a date range', ->
    result = enumerateDateRange(new Date('2010-10-10'), new Date('2010-11-10'))
    chai.assert.equal(result.length, 31)
    chai.assert.equal(""+result[0], ""+new Date('2010-10-10'))
    chai.assert.equal(""+result.slice(-1)[0], ""+new Date('2010-11-09'))

  it 'can convert sub-intervals to daily rates', ->
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    extendSubIntervalsWithValues(differentialIncidents, subIntervals)
    total = subIntervalsToDailyRates(subIntervals).slice(0, 5).reduce (sofar, [date, rate]) ->
      sofar + rate
    , 0
    chai.assert.equal(total, 40)

  it 'can convert sub-intervals to active cases', ->
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    extendSubIntervalsWithValues(differentialIncidents, subIntervals)
    maxRate = _.max(dailyRatesToActiveCases(subIntervalsToDailyRates(subIntervals), .9, {
      startDate: "2011-01-01"
      endDate: "2011-03-01"
    }), ([date, rate])->
      rate
    )
    chai.assert.equal(maxRate[0], "2011-01-04")

  it 'creates a timeseries that covers the given date window', ->
    norwalkIncidents = [
      {
        "_id": "6jAadicpuhkBvNEDd",
        "locations": [
          {
            "id": "6252001",
            "name": "United States",
            "latitude": 39.76,
            "longitude": -98.5,
            "featureClass": "A",
            "featureCode": "PCLI",
            "countryCode": "US",
            "admin1Code": "00",
            "population": 310232863,
            "countryName": "United States"
          }
        ],
        "dateRange": {
          "start": "2018-02-08T00:00:00.000Z",
          "end": "2018-02-09T00:00:00.000Z",
          "type": "day"
        },
        "cases": 1
      },
      {
        "_id": "o8rJrwcwBksQmodNF",
        "locations": [
          {
            "id": "4839822",
            "name": "Norwalk",
            "latitude": 41.1176,
            "longitude": -73.4079,
            "featureClass": "P",
            "featureCode": "PPL",
            "countryCode": "US",
            "admin1Code": "CT",
            "admin2Code": "001",
            "population": 88485,
            "admin2Name": "Fairfield County",
            "admin1Name": "Connecticut",
            "countryName": "United States"
          }
        ],
        "dateRange": {
          "start": "2018-02-08T00:00:00.000Z",
          "end": "2018-02-09T00:00:00.000Z",
          "type": "day"
        },
        "cases": 1
      },
      {
        "_id": "te3KQKMuh6T5L3dds",
        "locations": [
          {
            "id": "4839822",
            "name": "Norwalk",
            "latitude": 41.1176,
            "longitude": -73.4079,
            "featureClass": "P",
            "featureCode": "PPL",
            "countryCode": "US",
            "admin1Code": "CT",
            "admin2Code": "001",
            "population": 88485,
            "admin2Name": "Fairfield County",
            "admin1Name": "Connecticut",
            "countryName": "United States"
          }
        ],
        "dateRange": {
          "start": "2017-12-01T00:00:00.000Z",
          "end": "2018-02-18T00:00:00.000Z",
          "type": "precise"
        },
        "cases": 20,
        "type": "caseCount"
      }
    ]
    differentialIncidents = convertAllIncidentsToDifferentials(norwalkIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    extendSubIntervalsWithValues(differentialIncidents, subIntervals)
    locationTree = LocationTree.from(subIntervals.map (x) -> x.location)
    locationsToMaxSubintervals = mapLocationsToMaxSubIntervals(locationTree, subIntervals)
    locationsToActiveCases = _.object(_.map(locationsToMaxSubintervals, (s, locationId) ->
      [
        locationId,
        dailyRatesToActiveCases(subIntervalsToDailyRates(s), .9, {
          startDate: "2018-02-07"
          endDate: "2018-02-12"
        })
      ]
    ))
    _.zip(locationsToActiveCases["6252001"], locationsToActiveCases["4839822"]).forEach ([parent, child]) ->
      chai.assert.equal(parent[0], child[0])
      chai.expect(parent[1] + 0.1).to.be.above(child[1], parent[0])
