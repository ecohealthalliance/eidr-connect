import notify from '/imports/ui/notification'

module.exports =
  commonPostDeletionTasks: (error, objNameToDelete, modalName=null) ->
    if error
      notify('error', error.message)
      return
    modalId = if modalName then "##{modalName}" else "##{objNameToDelete}-delete-modal"
    $(modalId).modal('hide')
    $('body').removeClass('modal-open')
    $('.modal-backdrop').remove()
    notify('success', "The #{objNameToDelete} has been deleted.")
