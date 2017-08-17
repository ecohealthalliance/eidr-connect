Articles = require '/imports/collections/articles.coffee'
import { pluralize } from '/imports/utils'
import { getIncidentSnippet } from '/imports/ui/snippets'

Template.incidentReport.onCreated ->
  @subscribe('incidentArticle', @data.articleId)

Template.incidentReport.onCreated ->
  Meteor.defer =>
    @$('[data-toggle=tooltip]').tooltip
      delay: show: '200'
      container: 'body'

Template.incidentReport.helpers
  caseCounts: ->
    @deaths or @cases

  countLabel: ->
    if @type == 'activeCount'
      pluralize('Active Case', @cases, false)
    else if @cases
      pluralize('Case', @cases, false)
    else if @deaths
      pluralize('Death', @deaths, false)

  importantDetails: ->
    @deaths or @cases or @status

  incidentUrl: ->
    Articles.findOne(@articleId)?.url

  incidentContent: ->
    if @annotations
      article = Articles.findOne(@articleId)
      articleContent = article?.enhancements?.source.cleanContent.content
      if articleContent
        Spacebars.SafeString(getIncidentSnippet(articleContent, @))
