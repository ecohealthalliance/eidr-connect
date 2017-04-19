Articles = require '/imports/collections/articles.coffee'
import { pluralize } from '/imports/ui/helpers'

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
