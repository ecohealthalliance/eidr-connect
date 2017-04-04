import { formatLocation } from '/imports/ui/helpers'

Template.location.helpers
  formatDate: (date) ->
    return moment(date).format("MMM D, YYYY")

Template.location.events
  "click .proMedLink": (event, template) ->
    anchorNode = event.currentTarget
    url = anchorNode.getAttribute 'uri'
    if url
      $('#proMedIFrame').attr('src', url)
      $('#proMedURL').attr('href', url)
      $('#proMedURL').text(url)
      $('#proMedModal').modal("show")
