import regionToCountries from '/imports/regionToCountries.json'

locationContains = (locationA, locationB) ->
  props = [
    'countryName',
    'admin1Name',
    'admin2Name',
  ]
  if locationA.id == locationB.id
    return true
  if locationA.id == "6295630" # Earth
    return true
  if locationA.id of regionToCountries
    return locationB.countryCode in regionToCountries[locationA.id].countryISOs
  featureCode = locationA.featureCode
  if featureCode.startsWith("PCL")
    containmentLevel = 1
  else if featureCode.endsWith("1")
    containmentLevel = 2
  else if featureCode.endsWith("2")
    containmentLevel = 3
  else
    return false
  for prop in props.slice(0, containmentLevel)
    if locationB[prop] == ''
      return false
    if locationA[prop] != locationB[prop]
      return false
  return true

locationsToLocationTree = (locations) ->
  locationTree = new LocationTree("ROOT")
  locations.forEach (location) ->
    node = locationTree.search(location)
    if node.value?.id == location.id
      return
    contained = []
    uncontained = []
    for child, idx in node.children
      if locationContains(location, child.value)
        contained.push(child)
      else
        uncontained.push(child)
    if contained.length > 0
      node.children = uncontained.concat(new LocationTree(location, contained))
    else
      node.children.push(new LocationTree(location))
  return locationTree

# A tree of geoname locations where a node is the parent of another
# node if it's location contains the other node's location.
export default class LocationTree
  constructor: (@value, @children=[]) ->
    if @value != "ROOT"
      console.assert @value.id
      console.assert @value.featureCode

  # Return the location's node or the node that should be its parent.
  search: (location) ->
    if @value is "ROOT" or locationContains(@value, location)
      for subtree in @children
        containingNode = subtree.search(location)
        if containingNode
          return containingNode
      return @
    else
      return null

  # Return the node with the given id or null
  getNodeById: (locationId) ->
    if not locationId
      return null
    if @value.id == locationId
      return @
    else
      for subTree in @children
        result = subTree.getNodeById(locationId)
        if result
          return result
    return null

  getLocationById: (locationId) ->
    @getNodeById(locationId)?.value

  contains: (location) ->
    locationContains(@value, location)

LocationTree.from = locationsToLocationTree
LocationTree.locationContains = locationContains
