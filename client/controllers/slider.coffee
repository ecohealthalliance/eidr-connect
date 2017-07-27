import noUiSlider from 'nouislider'

formatMinMax = (min, max) ->
  # If max/min are dates, Convert to time (Number)
  min = if min?.getTime then min.getTime() else min
  max = if max?.getTime then max.getTime() else max
  [ min, max ]

Template.slider.onRendered ->
  slider = null
  sliderEl = @$('#slider')[0]

  if slider
    slider.destroy()

  sliderRange = @data.sliderRange.get()
  range = formatMinMax(sliderRange[0], sliderRange[1])

  slider = noUiSlider.create sliderEl,
    start: range
    behaviour: 'drag'
    connect: true
    range:
      min: range[0]
      max: range[1]

  sliderEl.noUiSlider.on 'change', _.debounce (values, handle) =>
    @data.selectedRange.set values
    # Show or hide the left/right slider icon
    $adjustRangeEl = $('.noUI-adjustRange')
    rangeWidth = $('.noUi-draggable').width() - $('.noUi-origin.noUi-background').width()
    $adjustRangeEl.css 'left', rangeWidth / 2
    if rangeWidth < $('.noUi-base').width() - 5
      $adjustRangeEl.removeClass 'hidden'
    else
      $adjustRangeEl.addClass 'hidden'
  , 250

  $('.noUi-draggable').append '<span class="noUI-adjustRange hidden"></span>'

  # Update the slider handle position when range from inputs change
  @autorun =>
    selectedRange = @data.selectedRange.get()
    slider.set(formatMinMax(selectedRange[0], selectedRange[1]))

  # Update the slider max and min if an incident is added
  @autorun =>
    sliderRange = @data.sliderRange.get()
    newMaxMin = formatMinMax(sliderRange[0], sliderRange[1])
    sliderEl.noUiSlider.updateOptions
      range:
        min: newMaxMin[0]
        max: newMaxMin[1]
