import { chai } from 'meteor/practicalmeteor:chai'
import solverExport from 'javascript-lp-solver'
import incidents from './incidents.coffee'
import convertAllIncidentsToDifferentials from './convertAllIncidentsToDifferentials.coffee'
import {
  differentailIncidentsToSubIntervals,
  subIntervalsToLP,
  intervalToEndpoints
} from './incidentResolution.coffee'

# When the solver is imported for the browser it uses the global namespace
# instead of exporting a handle.
if _.isEmpty solverExport
  Solver = solver
else
  Solver = solverExport

overlappingIncidents = [{
  cases: 40
  dateRange:
    start: new Date("Dec 31 2009")
    end: new Date("Jan 1 2011")
  locations: [
    admin1Name: "Maritime"
    countryName: "Togolese Republic"
    featureClass: "P"
    featureCode: "PPLC"
    id: "2365267"
    name: "Lomé"
  ]
}, {
  cases: 45
  dateRange:
    start: new Date("Dec 1 2010")
    end: new Date("Jan 1 2012")
  locations: [
    admin1Name: "Maritime"
    countryName: "Togolese Republic"
    featureClass: "P"
    featureCode: "PPLC"
    id: "2365267"
    name: "Lomé"
  ]
}]

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
      locations: [
        admin1Name: "Maritime"
        countryName: "Togolese Republic"
        featureClass: "P"
        featureCode: "PPLC"
        id: "2365267"
        name: "Lomé"
      ]
    }, {
      cases: 45
      dateRange:
        start: new Date("Dec 31 2009")
        end: new Date("Jan 1 2011")
      locations: [
        admin1Name: "Maritime"
        countryName: "Togolese Republic"
        featureClass: "P"
        featureCode: "PPLC"
        id: "2365267"
        name: "Lomé"
      ]
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

  it 'handles inconsistent counts', ->
    inconsistentIncidents = _.clone(overlappingIncidents)
    inconsistentIncidents.push
      cases: 40
      dateRange:
        start: new Date("Dec 1 2008")
        end: new Date("Jan 1 2013")
      locations: [
        admin1Name: "Maritime"
        countryName: "Togolese Republic"
        featureClass: "P"
        featureCode: "PPLC"
        id: "2365267"
        name: "Lomé"
      ]
    differentialIncidents = convertAllIncidentsToDifferentials(inconsistentIncidents)
    subIntervals = differentailIncidentsToSubIntervals(differentialIncidents)
    model = subIntervalsToLP(differentialIncidents, subIntervals)
    solution = Solver.Solve(Solver.ReformatLP(model))
    chai.assert(solution.s1 < 50)
    chai.assert(solution.s2 < 10)
    chai.assert(solution.s3 < 50)

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
