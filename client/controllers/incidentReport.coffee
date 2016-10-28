import { formatUrl } from '/imports/utils.coffee'

Template.incidentReport.helpers
  formatUrl: (url) ->
    formatUrl(url)

Template.addIncidentReport.events
  "click .open-incident-form": (event, template) ->
    Modal.show("incidentModal", {articles: template.data.articles, userEventId: template.data.userEvent._id, add: true})
