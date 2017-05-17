# Replace cumulative incident reports with differential incident reports
# created by taking the difference in counts between two subsequent cumulative
# reports in the same location.
convertAllIncidentsToDifferentials = (incidents)->
  cumulativeIncidents = []
  differentailIncidents = []
  incidents.forEach (i)->
    if not i.dateRange or i.specify
      return
    simpleIncident =
      startDate: new Date(i.dateRange.start)
      endDate: new Date(i.dateRange.end)
      count: i.cases or i.deaths
      type: _.keys(_.pick(i, 'cases', 'deaths', 'specify'))[0]
      locations: i.locations
      cumulative: i.dateRange.cumulative
      originalIncidents: [i]
    if not simpleIncident.count
      return
    simpleIncident.startDate.setUTCHours(0)
    simpleIncident.startDate.setUTCMinutes(0)
    simpleIncident.startDate.setUTCSeconds(0)
    simpleIncident.startDate.setUTCMilliseconds(0)
    # give the endDate a one hour offset before rounding it down to the start of
    # the day incase it is right before the end of the day.
    simpleIncident.endDate.setUTCMinutes(70)
    simpleIncident.endDate.setUTCHours(0)
    simpleIncident.endDate.setUTCMinutes(0)
    simpleIncident.endDate.setUTCSeconds(0)
    simpleIncident.endDate.setUTCMilliseconds(0)
    if i.dateRange.cumulative
      cumulativeIncidents.push(simpleIncident)
    else
      if simpleIncident.startDate > simpleIncident.endDate
        console.log(simpleIncident)
        throw new Error("Invalid incident")
      else if Number(simpleIncident.startDate) == Number(simpleIncident.endDate)
        simpleIncident.endDate.setUTCDate(simpleIncident.endDate.getUTCDate() + 1)
      differentailIncidents.push(simpleIncident)
  _.chain(cumulativeIncidents)
    .sortBy("endDate")
    .groupBy (i)->
      i.type + "," + (i?.locations or []).map((l)->l.id).sort()
    .forEach (incidentGroup, b)->
      # If two incidents have the same time offset, use the one with the
      # greater count.
      incidentGroup = incidentGroup.reduce((sofar, incident)->
        if sofar.length == 0
          return [incident]
        prevIncident = sofar.slice(-1)[0]
        dateDiff = Number(incident.endDate) - Number(prevIncident.endDate)
        if dateDiff > 0
          return sofar.concat(incident)
        else if dateDiff == 0
          if prevIncident.count >= incident.count
            return sofar
          else
            return sofar.slice(0,-1).concat(incident)
        else
          throw Error("endDates are not sorted.")
      , [])
      prevIncident = incidentGroup[0]
      for [incident, nextIncident] in _.zip(incidentGroup.slice(1), incidentGroup.slice(2))
        count = incident.count - prevIncident.count
        if count < 0
          # This cumulative count is less than prior counts.
          # A differential count cannot be created from it.
          if nextIncident and nextIncident.count < prevIncident.count
            # The next next two count are less than the previous count
            # so assume the cumulative counts have started over.
            prevIncident = incident
          continue
        newDifferential =
          type: incident.type
          locations: incident.locations
          cumulative: incident.cumulative
          count: count
          startDate: prevIncident.endDate
          endDate: incident.endDate
          originalIncidents: prevIncident.originalIncidents.concat(
            incident.originalIncidents)
        prevIncident = incident
        differentailIncidents.push(newDifferential)
  return differentailIncidents
module.exports = convertAllIncidentsToDifferentials
