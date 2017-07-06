Feeds = require('/imports/collections/feeds.coffee')
import { notify } from '/imports/ui/notification'

Template.feeds.onCreated ->
  @subscribe('feeds')

Template.feeds.onRendered ->
  $('.add-feed').parsley()

Template.feeds.helpers
  feeds: Feeds.find()

Template.feeds.events
  'submit .add-feed': (event, instance) ->
    return if event.isDefaultPrevented() # Form is invalid
    event.preventDefault()
    feedUrl = event.target.feedUrl.value
    if !/^https?:\/\//i.test(feedUrl)
      feedUrl = "http://#{feedUrl}"

    Meteor.call 'addFeed', url: feedUrl, (error, result) ->
      if error
        toastr.warning(error.reason)
      else
        toastr.success("#{feedUrl} has been added")
        event.target.reset()

  'click .delete': (event, instance) ->
    Modal.show 'confirmationModal',
      html: Spacebars.SafeString(Blaze.toHTMLWithData(
        Template.deleteConfirmationModalBody,
        objNameToDelete: 'feed'
        displayName: @url
      ))
      onConfirm: =>
        Meteor.call 'removeFeed', @_id, (error) ->
          if error
            notify('error', 'There was a problem updating your incidents.')
