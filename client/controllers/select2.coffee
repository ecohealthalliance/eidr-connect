Template.select2.onCreated ->
  defaultOptionFn = (params, callback)=>
    callback(results: @data.options or [])
  # A function that takes parameters for a term being typed calls a callback
  # with a list of corresponding options.
  @optionsFn = @data.optionsFn or defaultOptionFn
  @values = @data.values or new ReactiveVar([])

Template.select2.onRendered ->
  initialValues = []
  if @data.selected
    if _.isArray @data.selected
      initialValues = @data.selected
    else
      initialValues = [@data.selected]
  @values.set(initialValues)
  $.fn.select2.amd.require [
    'select2/data/array', 'select2/utils'
  ], (ArrayAdapter, Utils) =>
    CustomDataAdapter = ($element, options) ->
      CustomDataAdapter.__super__.constructor.call(@, $element, options)
    Utils.Extend(CustomDataAdapter, ArrayAdapter)
    CustomDataAdapter.prototype.query = _.throttle(@optionsFn, 600)

    @autorun =>
      values = @values.get()
      $input = @$("select")
      if $input.data('select2')
        $input.select2('close')
        $input.select2('destroy')
  
      $input.select2
        data: initialValues
        multiple: @data.multiple
        minimumInputLength: 0
        dataAdapter: CustomDataAdapter
        placeholder: @data.placeholder or ""

      if required
        if values.length > 0
          required = false
        @$('.select2-search__field').attr
          'required': required
          'data-error': 'Please select a value.'
      $input.val(values.map((x)->x.id)).trigger('change')

Template.select2.events
  'select2:open': (event, instance) ->
    unless $('.select2-results__additional-options').length
      $('.select2-dropdown').addClass('select2-dropdown--with-additional-options')
      Blaze.renderWithData Template.clearSelect2Control,
        onClick: ->
          instance.values.set([])
          instance.$('select').select2('close')
      , document.querySelector('.select2-results')

Template.clearSelect2Control.events
  'click button': (event, instance) ->
    instance.data.onClick()
