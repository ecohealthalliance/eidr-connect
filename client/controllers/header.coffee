Template.navLinks.helpers
  isCurator: ->
    Roles.userIsInRole(Meteor.userId(), ["admin", "curator"])

Template.navLinks.events
  'mouseover li.dropdown': (event) ->
    $(event.currentTarget).addClass('open')

  'mouseout li.dropdown': (event) ->
    $(event.currentTarget).removeClass('open')

  'click': (e) ->
    #check event.target's class to see if the click was meant to open/close a dropdown
    if $(e.target).hasClass('dropown') and $(e.target).hasClass('open')
      $(event.currentTarget).removeClass('open')

  'click #logOut': ->
    Meteor.logout()

  'click a': (event) ->
    event.currentTarget.blur()
