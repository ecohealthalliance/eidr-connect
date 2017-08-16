import { notify } from '/imports/ui/notification'

Template.createAccount.onRendered ->
  @$('#add-account').parsley()

Template.createAccount.events
  'submit #add-account': (event) ->
    return if event.isDefaultPrevented() # Form is invalid
    form = event.target
    event.preventDefault()
    name = form.name.value.trim()
    email = form.email.value.trim()
    makeAdmin = form.admin.checked

    Meteor.call 'createAccount', email, name, makeAdmin, (error, result) ->
      if error
        if error.error is 'allUsers.createAccount.exists'
          notify('error', 'The specified email address is already being used')
        else
          notify('error', error.error)
       else
         form.reset()
         notify('success', "Account created for #{email}")
