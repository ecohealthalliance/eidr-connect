import Articles from '/imports/collections/articles.coffee'
import IncidentReports from '/imports/collections/incidentReports.coffee'
import { ensureIndexes} from './dbUtils.coffee'

###
# indexes.coffee - provide a single location to ensure all db indexes on startup
###

Meteor.startup ->
  ensureIndexes(Articles, {url: 1, addedDate: 1})
  ensureIndexes(IncidentReports, {url: 1})
