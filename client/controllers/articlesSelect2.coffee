Template.articleSelect2.onRendered ->
  $input = @$('select')
  options = {}
  if @data.multiple
    options.multiple = true
  options.placeholder = @data.placeholder or ''
  $input.select2(options)

  if @data.selected
    $input.val(@data.selected).trigger('change')
  $input.next('.select2-container').css('width', '100%')

Template.articleSelect2.onDestroyed ->
  selectId = @data.selectId
  if selectId
    Meteor.defer ->
      @$("##{selectId}").select2('destroy')
