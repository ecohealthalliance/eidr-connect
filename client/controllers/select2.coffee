Template.select2.onCreated ->
  defaultOptionFn = (params, callback) =>
    console.log @data
    callback(results: @data.options or [])
  # A function that takes parameters for a term being typed calls a callback
  # with a list of corresponding options.
  @optionsFn = @data.optionsFn or defaultOptionFn
  @values = @data.values or new ReactiveVar([])

Template.select2.onRendered ->
  if @data.selected
    initialValues = []
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
        data: values
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
      $input.val(values.map((x) -> x.id)).trigger('change')

Template.select2.events
  'change select': (event, instance) ->
    selectedValues = instance.$("select").select2('data')
    uniqueValues = _.uniq(_.pluck(instance.values.get(), 'id'))
    uniqueSelectedValues = _.uniq(_.pluck(selectedValues, 'id'))
    intersection = _.intersection(uniqueValues, uniqueSelectedValues)
    if intersection.length != uniqueSelectedValues.length or uniqueValues.length != uniqueSelectedValues.length
      instance.values.set(selectedValues.map (data) ->
        id: data.id
        text: data.text
        item: data.item
      )

  'select2:open': (event, instance) ->
    controlTemplate = instance.data.controlTemplate or Template.clearSelect2Control
    unless $('.select2-results__additional-options').length
      $('.select2-dropdown').addClass('select2-dropdown--with-additional-options')
      Blaze.renderWithData controlTemplate,
        parentInstance: instance
      , document.querySelector('.select2-results')

Template.clearSelect2Control.events
  'click button': (event, instance) ->
    parentInstance = instance.data.parentInstance
    parentInstance.values.set([])
    parentInstance.$('select').select2('close')
