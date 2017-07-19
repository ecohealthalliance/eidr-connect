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
  , 500

  $('.noUi-draggable').append '<span class="noUI-adjustRange hidden"></span>'
