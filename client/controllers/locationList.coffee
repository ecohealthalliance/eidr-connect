Template.locationList.helpers
  incidentLocations: ->
    locations = {}
    counts = Template.instance().data.counts
    # Loop 1: Incident Reports ("counts")
    for count in counts
      # Loop 2: Locations within each "count" record
      for loc in count.locations
        if loc.geonameId in locations # Append the source, update the date
          mergedSources = _.union(loc.sources, count.url)
          currDate = new Date(locations[loc.geonameId].addedDate)
          newDate = new Date(date.parse count.addedDate)
          if currDate < newDate
            locations[loc.geonameId].addedDate = newDate
          locations[loc.geonameId].sources = mergedSources
        else # Insert new item
          loc.sources = count.url
          loc.addedDate = count.addedDate
          locations[loc.geonameId] = loc
    # Return
    _.values(locations)