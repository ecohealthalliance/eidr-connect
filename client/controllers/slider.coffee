import noUiSlider from 'nouislider'

formatMinMax = (min, max) ->
  # If max/min are dates, Convert to time (Number)
  min = if min?.valueOf then min.valueOf() else min
  max = if max?.valueOf then max.valueOf() else max
  [ min, max ]

Template.slider.onRendered ->
  slider = null
  sliderEl = @$('#slider')[0]

  @autorun =>
    if slider
      slider.destroy()

    sliderRange = @data.sliderRange.get()
    formattedSliderRange = formatMinMax(sliderRange[0], sliderRange[1])
    selectedRange = @data.selectedRange.get()
    if selectedRange
      range = formatMinMax(selectedRange[0], selectedRange[1])
    else
      range = formattedSliderRange

    slider = noUiSlider.create sliderEl,
      start: range
      behaviour: 'drag'
      connect: true
      range:
        min: formattedSliderRange[0]
        max: formattedSliderRange[1]

    sliderEl.noUiSlider.on 'change', _.debounce (values, handle) =>
      @data.selectedRange.set([Math.ceil(values[0]), Math.ceil(values[1])])
    , 250

    hidden = "hidden"
    sortedTimestamps = selectedRange
      .concat(sliderRange)
      .map(Number)
      .sort()
    # Assuming the selectedRange and sliderRange intervals are overlapping, this
    # determines the ratio of the interval formed by their intersection to the
    # interval formed by their union.
    overlapRatio = (sortedTimestamps[2] - sortedTimestamps[1]) / (sortedTimestamps[3] - sortedTimestamps[0])
    if overlapRatio < 0.9
      hidden = ""
    $('.noUi-draggable').append """<span class="noUI-adjustRange #{hidden}"></span>"""
