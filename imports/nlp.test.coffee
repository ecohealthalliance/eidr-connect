import { chai } from 'meteor/practicalmeteor:chai'
import {
    parseSents,
    getTerritories,
    annotationDistance,
    nearestAnnotation,
    createIncidentReportsFromEnhancements } from '/imports/nlp'

describe 'parseSents', ->
  it 'splits text into an array of sentences', ->
    result = parseSents("This is the first sentence. This is another one.")
    chai.expect(result).to.deep.equal([
      "This is the first sentence.",
      " This is another one."
    ])

describe 'nearestAnnotation', ->
  it 'finds the annotation nearest the given annotation', ->
    annotations = [
      textOffsets: [[5, 10]]
    ,
      textOffsets: [[15, 20]]
    ,
      textOffsets: [[25, 30]]
    ]
    result = nearestAnnotation({ textOffsets: [[21, 23]] }, annotations)
    chai.expect(result).to.deep.equal(textOffsets: [[15, 20]])
