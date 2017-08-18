import noUiSlider from 'nouislider'

formatMinMax = (min, max) ->
  # If max/min are dates, Convert to time (Number)
  min = if min?.valueOf then Math.ceil(min.valueOf()) else min
  max = if max?.valueOf then Math.ceil(max.valueOf()) else max
  [ min, max ]

Template.slider.onRendered ->
  slider = null
  sliderEl = @$('#slider')[0]

  if slider
    slider.destroy()

  # sliderRange is a ReactiveVar handed down from the parent template
  sliderRange = @data.sliderRange.get()
  formattedSliderRange = formatMinMax(sliderRange[0], sliderRange[1])

  slider = noUiSlider.create sliderEl,
    start: formattedSliderRange
    behaviour: 'drag'
    connect: true
    range:
      min: formattedSliderRange[0]
      max: formattedSliderRange[1]

  # Append slider element with adjust range icon
  $('.noUi-draggable').append('<span class="noUI-adjustRange hidden"></span>')

  sliderEl.noUiSlider.on 'change', _.debounce (values, handle) =>
    range = formatMinMax(values[0], values[1])
    @data.selectedRange.set(range)
  , 250

  @autorun =>
    selectedRange = @data.selectedRange.get()
    # Update the slider handle position when range from inputs change
    slider.set(formatMinMax(selectedRange[0], selectedRange[1]))
    hidden = true
    sortedTimestamps = selectedRange
      .concat(sliderRange)
      .map(Number)
      .sort()
    # Assuming the selectedRange and sliderRange intervals are overlapping, this
    # determines the ratio of the interval formed by their intersection to the
    # interval formed by their union.
    overlapRatio = (sortedTimestamps[2] - sortedTimestamps[1]) /
      (sortedTimestamps[3] - sortedTimestamps[0])
    if overlapRatio < 0.9
      hidden = false
    $adjustRange = $('.noUI-adjustRange')
    if hidden
      $adjustRange.addClass('hidden')
    else
      $adjustRange.removeClass('hidden')

  # Update the slider max and min if an incident is added
  @autorun =>
    sliderRange = @data.sliderRange.get()
    newMaxMin = formatMinMax(sliderRange[0], sliderRange[1])
    sliderEl.noUiSlider.updateOptions
      range:
        min: newMaxMin[0]
        max: newMaxMin[1]
