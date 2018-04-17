import { chai } from 'meteor/practicalmeteor:chai'
import incidents from './incidents.coffee'
import LocationTree from './LocationTree.coffee'

describe 'LocationTree', ->
  it 'deduplicates locations', ->
    myTree = LocationTree.from([{
      admin1Name: "Maritime"
      countryName: "Togolese Republic"
      featureClass: "P"
      featureCode: "PPLC"
      id: "2365267"
      name: "Lomé"
    }, {
      admin1Name: "Maritime"
      countryName: "Togolese Republic"
      featureClass: "P"
      featureCode: "PPLC"
      id: "2365267"
      name: "Lomé"
    }])
    chai.assert.equal(myTree.children.length, 1)
    chai.assert.equal(myTree.children[0].value.id, "2365267")
    chai.assert.equal(myTree.children[0].children.length, 0)

  it 'can build location trees from locations', ->
    locations = [{
      admin1Name: "Maritime"
      countryName: "Togolese Republic"
      featureClass: "P"
      featureCode: "PPLC"
      id: "2365267"
      name: "Lomé"
    }, {
      featureCode: "PCLI"
      featureClass: "A"
      name: "Togolese Republic"
      id: "2363686"
      countryName: "Togolese Republic"
    }]
    myTree = LocationTree.from(locations)
    chai.assert.equal(myTree.children[0].value.id, "2363686")
    chai.assert.equal(myTree.children.length, 1)
    chai.assert.equal(myTree.getNodeById("2365267").value.id, "2365267")

  it 'can build location trees from many locations', ->
    myTree = LocationTree.from([{
      admin1Name: "Tripura"
      countryName: "Republic of India"
      featureClass: "A"
      featureCode: "ADM1"
      id: "1254169"
      name: "Tripura"
    }, {
      admin1Name: "Uttar Pradesh"
      countryName: "Republic of India"
      featureClass: "A"
      featureCode: "ADM1"
      id: "1253626"
      name: "Uttar Pradesh"
    }, {
      countryName:"Republic of India"
      featureClass:"A"
      featureCode:"PCLI"
      id:"1269750"
      name:"Republic of India"
    }])
    chai.assert.equal(myTree.children[0].value.id, "1269750")
    chai.assert.equal(myTree.children.length, 1)
    chai.assert.equal(myTree.children[0].children.length, 2)

  it 'can build handle the earth', ->
    locations = [{
      id: "2080185",
      name: "Republic of the Marshall Islands",
      alternateNames: [],
      latitude: 7.113,
      longitude: 171.236,
      featureClass: "A",
      featureCode: "PCLF",
      countryCode: "MH",
      admin1Code: "00",
      population: 65859
    }, {
      id: "6295630",
      name: "Earth",
      alternateNames: [],
      latitude: 0,
      longitude: 0,
      featureClass: "L",
      featureCode: "AREA",
      population: 6814400000 }]
    myTree = LocationTree.from(locations)
    chai.assert.equal(myTree.children[0].value.id, "6295630")
    chai.assert.equal(myTree.children.length, 1)

  it 'does not place administrative divisions inside their seats', ->
    locations = [{
      "name": "Washoe County",
      "asciiName": "Washoe County"
      "id": "5709906",
      "latitude": 40.66542,
      "longitude": -119.6643,
      "featureClass": "A",
      "featureCode": "ADM2",
      "countryCode": "US",
      "cc2": "",
      "admin1Code": "NV",
      "admin2Code": "031",
      "admin3Code": "",
      "admin4Code": "",
      "population": 421407,
      "elevation": "1635",
      "dem": "1640",
      "timezone": "America/Los_Angeles",
      "admin2Name": "Washoe County",
      "admin1Name": "Nevada",
      "countryName": "United States"
    }, {
      "id": "5511077",
      "name": "Reno",
      "asciiName": "Reno",
      "latitude": 39.52963,
      "longitude": -119.8138,
      "featureClass": "P",
      "featureCode": "PPLA2",
      "countryCode": "US",
      "cc2": "",
      "admin1Code": "NV",
      "admin2Code": "031",
      "admin3Code": "",
      "admin4Code": "",
      "population": 241445,
      "elevation": "1373",
      "dem": "1380",
      "timezone": "America/Los_Angeles",
      "admin2Name": "Washoe County",
      "admin1Name": "Nevada",
      "countryName": "United States"
    }]
    chai.assert(LocationTree.locationContains(locations[0], locations[1]))
    chai.assert(not LocationTree.locationContains(locations[1], locations[0]))
