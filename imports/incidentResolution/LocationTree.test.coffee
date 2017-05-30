import { chai } from 'meteor/practicalmeteor:chai'
import incidents from './incidents.coffee'
import LocationTree from './LocationTree.coffee'

describe 'LocationTree', ->
  it 'can build location trees from locations', ->
    myTree = LocationTree.from([{
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
    }])
    chai.assert.equal(myTree.children[0].value.id, "2363686")
    chai.assert.equal(myTree.children.length, 1)
    chai.assert.equal(myTree.getNodeById("2365267").value.id, "2365267")

  it 'can build build location trees from many locations', ->
    myTree = LocationTree.from([{
      admin1Name: "Tripura"
      countryName: "Republic of India"
      featureClass: "A"
      featureCode: "ADM1"
      id: "1254169"
      name: "Tripura"
    }, {
      admin1Name: "Uttar Pradesh"
      alternateNames: Array(70)
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

