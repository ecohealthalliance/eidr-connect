import noUiSlider from 'nouislider'

Template.slider.onRendered ->
  slider = null
  sliderEl = @$('#slider')[0]

  if slider
    slider.destroy()

  dates = [ @data.sliderMin.getTime(), @data.sliderMax.getTime() ]
  slider = noUiSlider.create sliderEl,
    start: dates
    behaviour: 'drag'
    connect: true
    range:
      min: dates[0]
      max: dates[1]

  sliderEl.noUiSlider.on 'change', _.debounce (values, handle) =>
    @data.dateRange.set [
      new Date(Math.ceil(values[0]))
      new Date(Math.ceil(values[1]))
    ]
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

  # Update the slider handle position when dates from inputs change
  @autorun =>
    dateRange = @data.dateRange.get()
    slider.set [
      dateRange[0].getTime()
      dateRange[1].getTime()
    ]
