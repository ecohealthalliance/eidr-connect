import { chai } from 'meteor/practicalmeteor:chai'
import Solver from './LPSolver'
import incidents from './incidents.coffee'
import convertAllIncidentsToDifferentials from './convertAllIncidentsToDifferentials.coffee'
import {
  differentailIncidentsToSubIntervals,
  subIntervalsToLP,
  intervalToEndpoints
} from './incidentResolution.coffee'

lome =
  admin1Name: "Maritime"
  countryName: "Togolese Republic"
  featureClass: "P"
  featureCode: "PPLC"
  id: "2365267"
  name: "Lomé"

overlappingIncidents = [{
  cases: 40
  dateRange:
    start: new Date("Dec 31 2009")
    end: new Date("Jan 1 2011")
  locations: [lome]
}, {
  cases: 45
  dateRange:
    start: new Date("Dec 1 2010")
    end: new Date("Jan 1 2012")
  locations: [lome]
}]

inconsistentIncidents = _.clone(overlappingIncidents)
inconsistentIncidents.push
  cases: 40
  dateRange:
    start: new Date("Dec 1 2008")
    end: new Date("Jan 1 2013")
  locations: [lome]

describe 'Incident Resolution', ->

  it 'converts incidents to the correct number of differential incident intervals', ->
    differentialIncidents = convertAllIncidentsToDifferentials(incidents)
    chai.assert.equal(differentialIncidents.length, 286)

  it 'handles outlier cumulative counts', ->
    differentialIncidents = convertAllIncidentsToDifferentials([
      {
        deaths: 10
        dateRange:
          cumulative: true
          end: new Date("Jan 1 2012")
      }, {
        deaths: 15
        dateRange:
          cumulative: true
          end: new Date("Jan 10 2012")
      }, {
        deaths: 5
        dateRange:
          cumulative: true
          end: new Date("Jan 20 2012")
      }, {
        deaths: 20
        dateRange:
          cumulative: true
          end: new Date("Jan 24 2012")
      }
    ])
    chai.assert.equal(differentialIncidents.length, 2)

  it 'creates 3 subintervals for two overlapping incidents', ->
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidents)
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
    chai.assert.sameMembers(subIntervals[0].incidentIds, [0])
    chai.assert.sameMembers(subIntervals[1].incidentIds, [0, 1])
    chai.assert.sameMembers(subIntervals[2].incidentIds, [1])
    chai.assert.equal(subIntervals.length, 3)

  it 'creates 1 subinterval for two overlapping incidents that share a start date', ->
    overlappingIncidentsSharedStart = [{
      cases: 40
      dateRange:
        start: new Date("Dec 31 2009")
        end: new Date("Jan 1 2011")
      locations: [lome]
    }, {
      cases: 45
      dateRange:
        start: new Date("Dec 31 2009")
        end: new Date("Jan 1 2011")
      locations: [lome]
    }]
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidentsSharedStart)
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
    chai.assert.sameMembers(subIntervals[0].incidentIds, [0, 1])
    chai.assert.equal(subIntervals.length, 1)

  it 'allocates counts proportionately', ->
    differentialIncidents = convertAllIncidentsToDifferentials(overlappingIncidents)
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
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
        start: new Date("Jan 1 2009")
        end: new Date("Jan 1 2012")
      locations: [lome]
    }, {
      cases: 2
      dateRange:
        start: new Date("Jan 1 2010")
        end: new Date("Jan 1 2011")
      locations: [lome]
    }, {
      cases: 50
      dateRange:
        start: new Date("Dec 1 2011")
        end: new Date("Jan 1 2012")
      locations: [lome]
    }])
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
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
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
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
        start: new Date("Jan 1 2001")
        end: new Date("Jan 1 2002")
      locations: [lome]
    }, {
      cases: 1
      dateRange:
        start: new Date("Jan 1 2003")
        end: new Date("Jan 1 2004")
      locations: [lome]
    }, {
      cases: 1
      dateRange:
        start: new Date("Jan 1 2005")
        end: new Date("Jan 1 2006")
      locations: [lome]
    }]
    incidents = initialIncidents6Subintervals.concat(inconsistentIncidents)
    differentialIncidents = convertAllIncidentsToDifferentials(incidents)
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    chai.assert(solution.s7 < 50)
    chai.assert(solution.s8 < 10)
    chai.assert(solution.s9 < 50)

  it 'can resolve a large number of incidents', ->
    differentialIncidents = convertAllIncidentsToDifferentials(incidents).filter (i)->i.type == "deaths"
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    for key, value of solution
      if key.startsWith("s")
        subId = key.split("s")[1]
        subInterval = subIntervals[parseInt(subId)]

  it 'creates end points', ->
    differentialIncidents = convertAllIncidentsToDifferentials(incidents)
    endpoints = intervalToEndpoints(differentialIncidents[0])
    chai.assert(endpoints[0].isStart)
