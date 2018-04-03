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
  enumerateDateRange
} from './incidentResolution'

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
    chai.assert.equal("" + _.max(dailyRatesToActiveCases(subIntervalsToDailyRates(subIntervals), .9), ([date, rate])->
      rate
    )[0].toISOString().split('T')[0], "2011-01-04")
