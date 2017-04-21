Template.select2.onCreated ->
  defaultOptionFn = (params, callback)=>
    callback(results: @data.options or [])
  # A function that takes parameters for a term being typed calls a callback
  # with a list of corresponding options.
  @optionsFn = @data.optionsFn or defaultOptionFn

Template.select2.onRendered ->
  $input = @$("select")
  $.fn.select2.amd.require [
    'select2/data/array', 'select2/utils'
  ], (ArrayAdapter, Utils) =>
    CustomDataAdapter = ($element, options) ->
      CustomDataAdapter.__super__.constructor.call(@, $element, options)
    Utils.Extend(CustomDataAdapter, ArrayAdapter)
    CustomDataAdapter.prototype.query = _.debounce(@optionsFn, 600)

    initialValues = []
    if @data.selected
      if _.isArray @data.selected
        initialValues = @data.selected
      else
        initialValues = [@data.selected]

    $input.select2
      data: initialValues
      multiple: @data.multiple
      minimumInputLength: 0
      dataAdapter: CustomDataAdapter
      placeholder: @data.placeholder or ""

    required = @data.required
    if required
      @$('.select2-search__field').attr
        'required': required
        'data-error': 'Please select a value.'
      # Remove required attr when value is selected and add it back when all
      # values are removed/unselected
      $input.on 'change', =>
        required = false
        if @$('.select2-selection__rendered li').length is 1
          required = true
        @$('.select2-search__field').attr('required', required)
        @$('select').attr('required', required)

    $input.val(initialValues.map((x)->x.id)).trigger('change')
