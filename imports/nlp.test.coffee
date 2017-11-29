import { chai } from 'meteor/practicalmeteor:chai'
import {
    parseSents,
    getTerritories,
    annotationDistance,
    nearestAnnotation,
    createIncidentReportsFromEnhancements } from '/imports/nlp'


test_enhancements = {
  "source": {
    "cleanContent": {
      "content": "The health unit was notified of a positive case of Campylobacter jejuni on Fri 9 Jun 2017."
    }
  },
  "dateOfDiagnosis": "2017-09-08T14:14:20.893136",
  "diseases": [
    {
      "keywords": [
        {
          "score": 0.26079211111101114,
          "name": "campylobacter"
        },
        {
          "score": 0.03538006371376764,
          "name": "campylobacter jejuni"
        }
      ],
      "inferred_keywords": [],
      "name": "Campylobacter",
      "probability": 0.26318106718783596
    }
  ],
  "diagnoserVersion": "0.4.0",
  "features": [
    {
      "count": 1,
      "text": "case",
      "label": "case",
      "textOffsets": [
        [
          43,
          47
        ]
      ],
      "attributes": [
        "case"
      ],
      "type": "count"
    },
    {
      "modifiers": [
        "case"
      ],
      "text": "case",
      "cumulative": false,
      "value": "case",
      "textOffsets": [
        [
          43,
          47
        ]
      ],
      "type": "caseCount"
    },
    {
      "textOffsets": [
        [
          79,
          89
        ]
      ],
      "timeRange": {
        "beginISO": "2017-6-9",
        "endISO": "2017-6-10"
      },
      "type": "datetime",
      "name": "9 Jun 2017",
      "value": "9 Jun 2017"
    },
    {
      "textOffsets": [
        [
          51,
          71
        ]
      ],
      "type": "pathogens",
      "value": "campylobacter jejuni"
    },
    {
      "text": "Campylobacter jejuni",
      "resolutions": [
        {
          "entity_id": "tsn:958568",
          "weight": 1,
          "entity": {
            "type": "species",
            "id": "tsn:958568",
            "label": "Campylobacter jejuni"
          }
        }
      ],
      "type": "resolvedKeyword",
      "textOffsets": [
        [
          51,
          71
        ]
      ]
    }
  ]
}

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

describe 'createIncidentReportsFromEnhancements', ->
  it 'distinguishes single dates from precise date ranges', ->
    incidents = createIncidentReportsFromEnhancements(test_enhancements)
    chai.expect(incidents[0].dateRange).to.deep.equal(
      type: 'day'
      start: new Date("2017-6-9Z+0000")
      end: new Date("2017-6-10Z+0000")
    )
