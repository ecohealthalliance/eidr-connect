import createInlineDateRangePicker from '/imports/ui/inlineDateRangePicker'
import {
  setVariables,
  clearDateRange } from '/imports/ui/setRange'

Template.dateSelector.onRendered ->
  date = new Date()
  @picker = createInlineDateRangePicker @$('.date-picker-container'),
    autoUpdateInput: false
    locale: cancelLabel: "Clear"
    autoApply: true
    startDate: @data.dateVariables.get().dates[0] or date
    endDate: @data.dateVariables.get().dates[1] or date

Template.dateSelector.helpers
  dateFiltering: ->
    Template.instance().data.dateVariables.get().dates.length

Template.dateSelector.events
  'click .apply-date-filters': (event, instance) ->
    dateFormat = "M/D/YYYY"
    $target = $(event.target)
    picker = instance.picker
    start = picker.startDate
    end = picker.endDate
    if not end
      return alert("You must select an end date first.")
    $target.val(start.format(dateFormat) + " - " + end.format(dateFormat))
    setVariables instance, 'on', [start.toDate(), end.toDate()]
    instance.$(event.target).blur()

  'click .clear-date-filters': (event, instance) ->
    clearDateRange instance.picker
    setVariables instance, 'on', []
    instance.$(event.target).blur()
