Articles = require '/imports/collections/articles.coffee'
import { pluralize } from '/imports/ui/helpers'
import { getIncidentSnippet } from '/imports/ui/snippets'

Template.incidentReport.onCreated ->
  @subscribe 'incidentArticle', @data.articleId

Template.incidentReport.helpers
  caseCounts: ->
    @deaths or @cases

  deathsLabel: ->
    pluralize 'Death', @deaths, false

  casesLabel: ->
    pluralize 'Case', @cases, false

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
