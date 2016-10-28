###
# cleanUrl - takes an existing url and removes the last match of the applied
#   regular expressions.
#
# @param {string} existingUrl, the url to be cleaned
# @param {array} [regexps], (optional) an array of compiled regular expressions
# @returns {string} cleanedUrl, an url that has been cleaned
###
export cleanUrl = (existingUrl, regexps) ->
  regexps = regexps || [new RegExp('^(https?:\/\/)', 'i'), new RegExp('^(www\.)', 'i')]
  cleanedUrl = existingUrl
  regexps.forEach (r) ->
    found = false
    match = cleanedUrl.match(r)
    if match && match.length > 0
      cleanedUrl = cleanedUrl.replace(match[match.length-1], '')
  return cleanedUrl

###
# formatUrl - takes an cleaned url and adds 'http' so that a browser can open
#
# @param {string} existingUrl, the url to be formatted
# @returns {string} formattedUrl, an url that has 'http' added
###
export formatUrl = (existingUrl) ->
  regexp = new RegExp('^(https?:\/\/)', 'i')
  if regexp.test existingUrl
    return existingUrl
  else
    return 'http://' + existingUrl

export incidentReportFormToIncident = (form)->
  $form = $(form)
  $articleSelect = $(form.articleSource)
  if $form.find("#singleDate").hasClass("active")
    rangeType = "day"
    $pickerContainer = $form.find("#singleDatePicker")
  else
    rangeType = "precise"
    $pickerContainer = $form.find("#rangePicker")

  picker = $pickerContainer.data("daterangepicker")

  unless form.articleSource.checkValidity()
    toastr.error('Please select an article.')
    form.articleSource.focus()
    return
  unless form.incidentType.checkValidity()
    toastr.error('Please select an incident type.')
    form.incidentType.focus()
    return
  if form.count and form.count.checkValidity() is false
    toastr.error('Please provide a valid count.')
    form.count.focus()
    return
  if form.other and form.other.value.trim().length is 0
    toastr.error('Please specify the incident type.')
    form.other.focus()
    return

  incident = {
    species: form.species.value
    travelRelated: form.travelRelated.checked
    locations: []
    status: form.status.value
    dateRange: {
      type: rangeType
      start: picker.startDate.toDate()
      end: picker.endDate.toDate()
      cumulative: form.cumulative.checked
    }
  }
  if form.incidentType.value == "cases"
    incident.cases = parseInt(form.count.value, 10)
  else if form.incidentType.value == "deaths"
    incident.deaths = parseInt(form.count.value, 10)
  else if form.incidentType.value == "other"
    incident.specify = form.other.value.trim()
  else
    throw new Meteor.Error("unknown-type")

  for child in $articleSelect.select2("data")
    if child.selected
      incident.url = [child.text.trim()]

  $loc = $(form).find("#incident-location-select2")
  for option in $loc.select2("data")
    item = option.item
    if typeof item.alternateNames is "string"
      delete item.alternateNames
    incident.locations.push(item)
  return incident

export UTCOffsets =
  ADT:  '-0300'
  AKDT: '-0800'
  AKST: '-0900'
  AST:  '-0400'
  CDT:  '-0500'
  CST:  '-0600'
  EDT:  '-0400'
  EGST: '+0000'
  EGT:  '-0100'
  EST:  '-0500'
  HADT: '-0900'
  HAST: '-1000'
  MDT:  '-0600'
  MST:  '-0700'
  NDT:  '-0230'
  NST:  '-0330'
  PDT:  '-0700'
  PMDT: '-0200'
  PMST: '-0300'
  PST:  '-0800'
  WGST: '-0200'
  WGT: '-0300'

export regexEscape = (s)->
  # Based on bobince's regex escape function.
  # source: http://stackoverflow.com/questions/3561493/is-there-a-regexp-escape-function-in-javascript/3561711#3561711
  s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
