createInlineDateRangePicker = ($parentElement, options) ->
  parentId = $parentElement.prop("id")
  if !parentId
    # If the parent element doesn't have an id, generate one
    parentId = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
      r = Math.random()*16|0
      v = if c is 'x' then r else (r&0x3|0x8)
      return v.toString(16)
    $parentElement.prop('id', parentId)

  locale =
    daysOfWeek: ['S','M','T','W','T','F','S']

  if !options then options = {}
  allOptions = _.extend
    parentEl: '#' + parentId
    template: Blaze.toHTML(Template.inlineDateRangePicker)
    singleDatePicker: options.singleDatePicker
    autoUpdateInput: false
    maxDate: options.maxDate
    minDate: options.minDate
    locale: locale
  , _.omit(options, 'singleDatePicker')

  if options.startDate and options.endDate
    allOptions.startDate = options.startDate
    allOptions.endDate = options.endDate

  if options.autoApply
    allOptions.autoApply = true

  $rangeContainer = $parentElement.daterangepicker(allOptions)
  picker = $rangeContainer.data('daterangepicker')

  $rangeContainer.find('.calendar')
    .off('click.daterangepicker', '.next')
    .off('click.daterangepicker', '.prev')
    .on 'click.daterangepicker', '.next', (event) ->
      picker.clickNext(event)
    .on 'click.daterangepicker', '.prev', (event) ->
      picker.clickPrev(event)

  if options.singleDatePicker
    $('.singleDatePickerInput').show()
    picker.clickApply = (event) ->
      @setEndDate(@startDate)
      @updateView()
      @element.trigger('apply.daterangepicker', @);

  # Prevent the calendar from hiding
  picker.hide = -> @

  $('.inlineRangePicker').off('click.daterangepicker')
  $('.inlineRangePicker .daterangepicker').removeClass('opensright')

  picker.show()

  $(document).off('mousedown.daterangepicker touchend.daterangepicker click.daterangepicker focusin.daterangepicker')

  picker


module.exports = createInlineDateRangePicker
