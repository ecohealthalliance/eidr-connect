import Articles from '/imports/collections/articles.coffee'
import IncidentReports from '/imports/collections/incidentReports.coffee'
import CuratorSources from '/imports/collections/curatorSources.coffee'
import { attemptBulkUpdate } from './dbUtils.coffee'
import { cleanUrl } from '/imports/utils.coffee'

###
# updateUrls - looks for `https?` and `(www.)` patterns within the url
#   property of the specified collection. @note this requires that the document
#   has a `url` property as either a string or an array
#
# @param {object} collection, the mongo collection to search aggregately
# @param {string} host, the hostname of the url to clean
# @param {string} domain, the domain of the url to clean
###
updateUrls = (collection, host, domain) ->
  bulkUpdates = []
  parts = [new RegExp('^(?:https?:\/\/)', 'i'), new RegExp("^(www\.)#{host}\.#{domain}", 'i')]
  full = new RegExp("^(https?:\/\/)?(www\.)?\\S+#{host}\.#{domain}", 'i')
  query = {url: {$regex: full}}
  cursor = collection.find(query)
  len = cursor.count()
  if len <= 0
    return
  cursor.forEach (d) ->
    if _.isArray(d.url)
      hasAnyBeenModified = false
      cleaned = []
      d.url.forEach (url) ->
        if full.test(url)
          cleanedUrl = cleanUrl(url, parts)
          if cleanedUrl != url
            hasAnyBeenModified = true
        # we will overwrite the entire array of links, so all urls are pushed
        cleaned.push(cleanedUrl)
      if hasAnyBeenModified
        bulkUpdates.push([d._id, {$set: {url: cleaned}}])
    else
      # working with a single value
      if full.test(d.url)
        cleanedUrl = cleanUrl(d.url, parts)
        if cleanedUrl != d.url
          bulkUpdates.push([d._id, {$set: {url: cleanedUrl}}])
  if bulkUpdates.length > 0
    attemptBulkUpdate(collection, bulkUpdates)

###
# updateMetadataLinks - looks for `https?` and `www.` patterns within the url
#   property of the specified collection. @note this requires that the document
#   has a `metadata.links` property as an array
#
# @param {object} collection, the mongo collection to search aggregately
# @param {string} host, the hostname of the url to clean
# @param {string} domain, the domain of the url to clean
###
updateMetadataLinks = (collection, host, domain) ->
  bulkUpdates = []
  parts = [new RegExp('^(?:https?:\/\/)', 'i'), new RegExp("^(www\.)#{host}\.#{domain}", 'i')]
  full = new RegExp("^(https?:\/\/)?(www\.)?\\S+#{host}\.#{domain}", 'i')
  query = {'metadata.links': {$regex: full }}
  cursor = collection.find(query)
  len = cursor.count()
  if len <= 0
    return
  cursor.forEach (d) ->
    if _.isArray(d.metadata.links)
      hasAnyBeenModified = false
      cleaned = []
      d.metadata.links.forEach (url) ->
        cleanedUrl = url
        if full.test(url)
          cleanedUrl = cleanUrl(url, parts)
          if cleanedUrl != url
            hasAnyBeenModified = true
        # we will overwrite the entire array of links, so all urls are pushed
        cleaned.push(cleanedUrl)
      # flag, if anything has changed?
      if hasAnyBeenModified
        bulkUpdates.push([d._id, {$set: {'metadata.links': cleaned}}])
  if bulkUpdates.length > 0
    attemptBulkUpdate(collection, bulkUpdates)

###
# cleanPromedUrls - finds and cleans promedmail urls from `Articles`, `IncidentReports` and
#   `CuratorSources` urls/links properties.
###
cleanPromedUrls = ->
    host = 'promedmail'
    domain = 'org'
    updateUrls(Articles, host, domain)
    updateUrls(IncidentReports, host, domain)
    updateMetadataLinks(CuratorSources, host, domain)

if Meteor.isServer
  Meteor.startup ->
    cleanPromedUrls()
