diseaseURIToCannonicalURI = {
  "http://purl.obolibrary.org/obo/DOID_060478": "http://purl.obolibrary.org/obo/DOID_0060478"
}
module.exports = (diseaseURI)=>
  diseaseURIToCannonicalURI[diseaseURI] or diseaseURI
