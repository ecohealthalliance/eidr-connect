import Articles from '/imports/collections/articles.coffee'
import IncidentReports from '/imports/collections/incidentReports.coffee'
import CuratorSources from '/imports/collections/curatorSources.coffee'
import { ensureIndexes} from './dbUtils.coffee'

###
# indexes.coffee - provide a single location to ensure all db indexes on startup
###

Meteor.startup ->
  ensureIndexes(Articles, {url: 1})
  ensureIndexes(IncidentReports, {url: 1})
  ensureIndexes(CuratorSources, {'metadata.links': 1})
