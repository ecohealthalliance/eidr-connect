import { chai } from 'meteor/practicalmeteor:chai'
import Solver from './LPSolver'
import incidents from './incidents'
import convertAllIncidentsToDifferentials from './convertAllIncidentsToDifferentials'
import {
  differentialIncidentsToSubIntervals,
  subIntervalsToLP,
  intervalToEndpoints,
  removeOutlierIncidents,
  createSupplementalIncidents,
  extendSubIntervalsWithValues
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
    start: new Date("Dec 31 2009 UTC")
    end: new Date("Jan 1 2011 UTC")
  locations: [lome]
}, {
  cases: 45
  dateRange:
    start: new Date("Dec 1 2010 UTC")
    end: new Date("Jan 1 2012 UTC")
  locations: [lome]
}]

inconsistentIncidents = _.clone(overlappingIncidents)
inconsistentIncidents.push
  cases: 40
  dateRange:
    start: new Date("Dec 1 2008 UTC")
    end: new Date("Jan 1 2013 UTC")
  locations: [lome]

describe 'Incident Resolution', ->

  it 'converts incidents to the correct number of differential incident intervals', ->
    differentialIncidents = convertAllIncidentsToDifferentials(incidents)
    chai.assert.equal(differentialIncidents.length, 285)

  it 'handles outlier cumulative counts', ->
    differentialIncidents = convertAllIncidentsToDifferentials([
      {
        deaths: 10
        dateRange:
          cumulative: true
          end: new Date("Jan 1 2012 UTC")
      }, {
        deaths: 15
        dateRange:
          cumulative: true
          end: new Date("Jan 10 2012 UTC")
      }, {
        deaths: 5
        dateRange:
          cumulative: true
          end: new Date("Jan 20 2012 UTC")
      }, {
        deaths: 20
        dateRange:
          cumulative: true
          end: new Date("Jan 24 2012 UTC")
      }
    ])
    chai.assert.equal(differentialIncidents.length, 2)

  it 'creates 3 subintervals for two overlapping incidents', ->
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    chai.assert.sameMembers(subIntervals[0].incidentIds, [0])
    chai.assert.sameMembers(subIntervals[1].incidentIds, [0, 1])
    chai.assert.sameMembers(subIntervals[2].incidentIds, [1])
    chai.assert.equal(subIntervals.length, 3)

  it 'creates 1 subinterval for two overlapping incidents that share a start date', ->
    overlappingIncidentsSharedStart = [{
      cases: 40
      dateRange:
        start: new Date("Dec 31 2009 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }, {
      cases: 45
      dateRange:
        start: new Date("Dec 31 2009 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }]
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidentsSharedStart)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    chai.assert.sameMembers(subIntervals[0].incidentIds, [0, 1])
    chai.assert.equal(subIntervals.length, 1)

  it 'allocates counts proportionately', ->
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    chai.assert(solution.s0 < 50)
    chai.assert(solution.s1 < 10)
    chai.assert(solution.s2 < 50)

  # This tests an problem that occurs when using an incident min/max rate
  # squeezing objective function. With such an objective function, it would
  # cause the minimum and maximum values of the first incident to be constrained
  # which would cause some of its subintervals to have unbalanced counts.
  # The current absolute value based objective function resolves this issue.
  it 'allocates counts proportionately 2', ->
    differentialIncidents = convertAllIncidentsToDifferentials([{
      cases: 100
      dateRange:
        start: new Date("Jan 1 2009 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }, {
      cases: 2
      dateRange:
        start: new Date("Jan 1 2010 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }, {
      cases: 50
      dateRange:
        start: new Date("Dec 1 2011 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }])
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    lomeIntervalIds = subIntervals
      .filter (s) -> s.location.id == lome.id
      .map (s) -> s.id
    chai.assert(solution["s#{lomeIntervalIds[0]}"] > 15)
    chai.assert(solution["s#{lomeIntervalIds[1]}"] > 2)
    chai.assert(solution["s#{lomeIntervalIds[2]}"] > 15)
    chai.assert(solution["s#{lomeIntervalIds[3]}"] >= 50)

  it 'handles inconsistent counts', ->
    differentialIncidents = convertAllIncidentsToDifferentials(inconsistentIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    chai.assert(solution.s1 < 50)
    chai.assert(solution.s2 < 10)
    chai.assert(solution.s3 < 50)


  # Test that adding prior non-overlapping incidents doesn't affect
  # handling of inconsistent incidents.
  it 'handles inconsistent counts with prior incidents', ->
    initialIncidents6Subintervals = [{
      cases: 1
      dateRange:
        start: new Date("Jan 1 2001 UTC")
        end: new Date("Jan 1 2002 UTC")
      locations: [lome]
    }, {
      cases: 1
      dateRange:
        start: new Date("Jan 1 2003 UTC")
        end: new Date("Jan 1 2004 UTC")
      locations: [lome]
    }, {
      cases: 1
      dateRange:
        start: new Date("Jan 1 2005 UTC")
        end: new Date("Jan 1 2006 UTC")
      locations: [lome]
    }]
    allIncidents = initialIncidents6Subintervals.concat(inconsistentIncidents)
    differentialIncidents = convertAllIncidentsToDifferentials(allIncidents)
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    chai.assert(solution.s7 < 50)
    chai.assert(solution.s8 < 10)
    chai.assert(solution.s9 < 50)

  it 'can resolve a large number of incidents', ->
    @timeout(5000)
    differentialIncidents = convertAllIncidentsToDifferentials(incidents).filter (i)->i.type == "deaths"
    subIntervals = differentialIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))

  it 'creates end points', ->
    differentialIncidents = convertAllIncidentsToDifferentials(incidents)
    endpoints = intervalToEndpoints(differentialIncidents[0])
    chai.assert(endpoints[0].isStart)

  it 'can remove outlier incidents', ->
    baseIncidents = [{
      cases: 50
      dateRange:
        start: new Date("Dec 31 2009 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }, {
      cases: 50
      dateRange:
        start: new Date("Dec 31 2009 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }, {
      cases: 45
      dateRange:
        start: new Date("Dec 31 2010 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }]
    constrainingIncidents = [{
      cases: 45
      dateRange:
        start: new Date("Dec 1 2009 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }]
    result = removeOutlierIncidents(baseIncidents, constrainingIncidents)
    chai.assert(result[0] == baseIncidents[2])

  it 'can create supplemental incidents', ->
    baseIncidents = [{
      cases: 41
      dateRange:
        start: new Date("Dec 31 2010 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }]
    constrainingIncidents = [{
      cases: 45
      dateRange:
        start: new Date("Dec 1 2009 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }]
    result = createSupplementalIncidents(baseIncidents, constrainingIncidents)
    chai.assert.equal(result[0].count, 4)
    chai.assert.equal("" + result[0].startDate, "" + new Date("Dec 1 2009 UTC"))
    chai.assert.equal("" + result[0].endDate, "" + new Date("Dec 31 2010 UTC"))

  it 'can handle empty incident arrays', ->
    baseIncidents = [{
      cases: 41
      dateRange:
        start: new Date("Dec 31 2010")
        end: new Date("Jan 1 2012")
      locations: [lome]
    }]
    constrainingIncidents = []
    result = createSupplementalIncidents(baseIncidents, constrainingIncidents)
    chai.assert(result.length == 0)
    result = removeOutlierIncidents(baseIncidents, constrainingIncidents)
    chai.assert(result[0] == baseIncidents[0])
    constrainingIncidents = [{
      cases: 45
      dateRange:
        start: new Date("Dec 1 2009 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }]
    result = createSupplementalIncidents([], constrainingIncidents)
    chai.assert.equal(result[0].count, 45)
    chai.assert.equal("" + result[0].startDate, "" + new Date("Dec 1 2009 UTC"))
    chai.assert.equal("" + result[0].endDate, "" + new Date("Jan 1 2012 UTC"))

  it 'can fit an incident set to constraining incidents', ->
    baseIncidents = [{
      cases: 15
      dateRange:
        start: new Date("Dec 1 2008 UTC")
        end: new Date("Dec 10 2008 UTC")
      locations: [tongo]
    }, {
      cases: 15
      dateRange:
        start: new Date("Nov 1 2008 UTC")
        end: new Date("Nov 2 2008 UTC")
      locations: [tongo]
    }, {
      cases: 4
      dateRange:
        start: new Date("Dec 20 2008 UTC")
        end: new Date("Jan 20 2009 UTC")
      locations: [lome]
    }]
    constrainingIncidents = [{
      cases: 20
      dateRange:
        start: new Date("Jan 1 2008 UTC")
        end: new Date("Jan 1 2009 UTC")
      locations: [tongo]
    }, {
      cases: 10
      dateRange:
        start: new Date("Jan 1 2009 UTC")
        end: new Date("Jan 1 2010 UTC")
      locations: [tongo]
    }]
    incidentsWithoutOutliers = removeOutlierIncidents(baseIncidents, constrainingIncidents)
    supplementalIncidents = createSupplementalIncidents(incidentsWithoutOutliers, constrainingIncidents)
    combinedIncidents = convertAllIncidentsToDifferentials(incidentsWithoutOutliers)
     .concat(supplementalIncidents)
    subIntervals = differentialIncidentsToSubIntervals(combinedIncidents)
    extendSubIntervalsWithValues(combinedIncidents, subIntervals)
    total = subIntervals
      .filter (x) -> x.location == tongo
      .reduce (sofar, x) ->
        sofar + x.value
      , 0
    chai.assert.equal(Math.round(total), 30)
    chai.assert.equal(subIntervals[0].start, Number(new Date("Jan 1 2008 UTC")))
    chai.assert.equal(subIntervals.slice(-1)[0].end, Number(new Date("Jan 1 2010 UTC")))

  it 'can remove statistical outlier incidents', ->
    baseIncidents = [{
      cases: 9
      dateRange:
        start: new Date("Oct 3 2010 UTC")
        end: new Date("Dec 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 6
      dateRange:
        start: new Date("Nov 3 2010 UTC")
        end: new Date("Nov 19 2010 UTC")
      locations: [lome]
    }, {
      cases: 1500000
      dateRange:
        start: new Date("Jan 3 2010 UTC")
        end: new Date("Oct 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 15
      dateRange:
        start: new Date("Aug 3 2010 UTC")
        end: new Date("Oct 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 1
      dateRange:
        start: new Date("Feb 20 2010 UTC")
        end: new Date("Apr 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 2
      dateRange:
        start: new Date("Jan 20 2010 UTC")
        end: new Date("Apr 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 50
      dateRange:
        start: new Date("Dec 31 2009 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }, {
      cases: 50
      dateRange:
        start: new Date("Dec 31 2009 UTC")
        end: new Date("Jan 1 2011 UTC")
      locations: [lome]
    }, {
      cases: 45
      dateRange:
        start: new Date("Dec 31 2010 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }, {
      cases: 45
      dateRange:
        start: new Date("Dec 1 2009 UTC")
        end: new Date("Jan 1 2012 UTC")
      locations: [lome]
    }]
    result = removeOutlierIncidents(baseIncidents, [])
    chai.assert.equal(result.length, 9)

  it 'can use cumulative incidents to remove outliers', ->
    baseIncidents = [{
      cases: 9
      dateRange:
        start: new Date("Oct 3 2010 UTC")
        end: new Date("Dec 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 6
      dateRange:
        start: new Date("Nov 3 2010 UTC")
        end: new Date("Nov 19 2010 UTC")
      locations: [lome]
    }, {
      cases: 1500000
      dateRange:
        start: new Date("Jan 3 2010 UTC")
        end: new Date("Oct 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 11
      dateRange:
        start: new Date("Aug 3 2010 UTC")
        end: new Date("Oct 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 2
      dateRange:
        start: new Date("Jan 20 2010 UTC")
        end: new Date("Apr 10 2010 UTC")
      locations: [lome]
    }, {
      cases: 5
      dateRange:
        end: new Date("Jan 1 2009 UTC")
        cumulative: true
      locations: [lome]
    }, {
      cases: 65
      dateRange:
        end: new Date("Jan 1 2011 UTC")
        cumulative: true
      locations: [lome]
    }]
    result = removeOutlierIncidents(baseIncidents, [])
    console.log(result)
    chai.assert.equal(result.length, 6)
