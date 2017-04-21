setVariables = (instance, type, dates) ->
  variables = instance.data.dateVariables
  _variables = variables.get()
  _variables.searchType = type
  _variables.dates = dates
  variables.set _variables
  instance.data.filtering.set true

clearDateRange = (picker) ->
  date = new Date()
  picker.setStartDate date
  picker.setEndDate date
  picker.updateFormInputs()
  picker.updateCalendars()

updateCalendarSelection = (picker, range) ->
  {startDate, endDate} = range
  currentMonth = moment(month: moment().month())
  lastMonth = moment(month: moment().subtract(1, 'months').month())
  picker.rightCalendar.month = currentMonth
  picker.leftCalendar.month = lastMonth
  picker.setStartDate(startDate)
  picker.setEndDate(endDate)
  picker.updateCalendars()

module.exports =
  setVariables: setVariables
  clearDateRange: clearDateRange
  updateCalendarSelection: updateCalendarSelection
