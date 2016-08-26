@Counts = new Meteor.Collection "counts"
@grid ?= {}
@grid.Counts = Counts

getEventCounts = (userEventId) ->
  Counts.find({userEventId: userEventId})

Counts.getEventCounts = getEventCounts

if Meteor.isServer
  Meteor.publish "eventCounts", (ueId) ->
    getEventCounts(ueId)
  Meteor.publish "mapIncidents", () ->
    Counts.find({date: {$ne: null}}, {fields: {userEventId: 1, date: 1}})

  Counts.allow
    insert: (userID, doc) ->
      doc.creationDate = new Date()
      return Roles.userIsInRole(Meteor.userId(), ['admin'])
    remove: (userID, doc) ->
      return Roles.userIsInRole(Meteor.userId(), ['admin'])

Meteor.methods
  addIncidentReport: (eventId, url, locations, type, value, date, travel) ->
    if url.length
      insertCount = {
        url: [url],
        userEventId: eventId,
        travelRelated: travel
      }

      if locations.length
        insertCount.locations = locations

      user = Meteor.user()
      insertCount.addedByUserId = user._id
      insertCount.addedByUserName = user.profile.name
      insertCount.addedDate = new Date()

      if date.length
        insertCount.date = moment(date, "M/D/YYYY").toDate()

      switch type
        when "cases" then insertCount.cases = value
        when "deaths" then insertCount.deaths = value
        else insertCount.specify = value
      newId = Counts.insert(insertCount)
      Meteor.call("updateUserEventLastModified", eventId)
      return newId

  removeEventCount: (id) ->
    if Meteor.user()
      removed = Counts.findOne(id)
      Counts.remove(id)
      #Meteor.call("removeOrphanedLocations", removed.userEventId, id)
      Meteor.call("updateUserEventLastModified", removed.userEventId)
