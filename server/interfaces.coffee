Meteor.methods
  getArticleLocations: (url) ->
    geonameIds = []
    placeNames = []
    locations = []
    
    result = HTTP.call("POST", "http://grits.eha.io:80/api/v1/public_diagnose", {params: {api_key: "grits28754", url: url}})
    if result.data and result.data.features
      for object in result.data.features
        if object.geoname
          geonameIds.push(object.geoname.geonameid.toString())
          placeNames.push(object.geoname.name)
    
    if geonameIds.length
      geonameLocations = HTTP.call("GET", "https://api.geonames.org/searchJSON", {
        params: {
          name: placeNames.toString(),
          username: "eha_eidr",
          style: "full",
          operator: "or"
        }
      })
      
      if geonameLocations.data
        for loc in geonameLocations.data.geonames
          if geonameIds.indexOf(loc.geonameId.toString()) isnt -1
            locations.push({
              geonameId: loc.geonameId.toString(),
              name: loc.name,
              displayName: loc.toponymName,
              subdivision: loc.adminName1,
              latitude: loc.lat,
              longitude: loc.lng,
              countryName: loc.countryName,
              url: Meteor.call("generateGeonamesUrl", loc.geonameId)
            })
    return locations