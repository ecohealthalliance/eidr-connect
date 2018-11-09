LocationTree = require('./LocationTree')
_ = require('underscore')
MILLIS_PER_DAY = 1000 * 60 * 60 * 24

class DifferentialIncident
  constructor: (incident) ->
    # Check if the incident has all the properties needed to define a
    # differential incident. If not default to converting a regular
    # incident.
    properties = [
      'startDate',
      'endDate',
      'count',
      'type',
      'locations',
      'cumulative',
      'originalIncidents'
    ]
    if properties.every((p) -> p of incident)
      for prop in properties
        @[prop] = incident[prop]
    else
      @startDate = new Date(incident.dateRange.start)
      @startDate.setUTCHours(0)
      @startDate.setUTCMinutes(0)
      @startDate.setUTCSeconds(0)
      @startDate.setUTCMilliseconds(0)
      # Give the endDate a one hour offset before rounding it down to the start
      # of the day incase it is right before the end of the day.
      @endDate = new Date(incident.dateRange.end)
      @endDate.setUTCMinutes(70)
      @endDate.setUTCHours(0)
      @endDate.setUTCMinutes(0)
      @endDate.setUTCSeconds(0)
      @endDate.setUTCMilliseconds(0)
      if @startDate > @endDate
        console.log(incident)
        throw new Error("Invalid incident: Dates out of order.")
      else if Number(@startDate) == Number(@endDate) and not incident.dateRange.cumulative
        # Convert single day incidents to one day long date ranges
        @endDate.setUTCDate(@endDate.getUTCDate() + 1)
      @count = incident.cases or incident.deaths
      @type = _.keys(_.pick(incident, 'cases', 'deaths'))[0]
      # Remove duplicate/contained locations from location array
      @locations = LocationTree.from(incident.locations or []).children.map (x) ->
        x.value
      @cumulative = incident.dateRange.cumulative
      @originalIncidents = [incident]
    @initialize()
  initialize: () ->
    @duration = (Number(@endDate) - Number(@startDate)) / MILLIS_PER_DAY
    # The case rate is divided by the number of locations in the incident
    # so that a report of cases distributed in 3 states won't result in
    # a count of triple that for the country.
    @rate = @count / @duration / @locations.length
    @diseaseId = @originalIncidents[0].resolvedDisease?.id
    return @
  truncated: (dateRange) ->
    newStartDate = new Date(@startDate)
    newEndDate = new Date(@endDate)
    if @startDate < dateRange.start
      newStartDate = new Date(dateRange.start)
    if @endDate > dateRange.end
      newEndDate = new Date(dateRange.end)
    newDuration = (Number(newEndDate) - Number(newStartDate)) / MILLIS_PER_DAY
    @clone({
      startDate: newStartDate
      endDate: newEndDate
      count: @count * newDuration / @duration
    })
  clone: (extendProps={}) ->
    clonedIncident = Object.create(@)
    _.extend(clonedIncident, extendProps)
    clonedIncident.initialize()
    
module.exports = DifferentialIncident
