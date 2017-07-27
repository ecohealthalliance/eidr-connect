import { notify } from '/imports/ui/notification'
import { stageModals } from '/imports/ui/modals'

Template.addGeonameModal.onCreated ->
  @latLon = new ReactiveVar()
  @parentLocation = new ReactiveVar([])
  @onAdded = (x)-> x
  if @data.onAdded
    @onAdded = @data.onAdded
  @modals =
    currentModal:
      element: '#addGeonameModal'
    previousModal:
      element: @data.parentModal
      add: 'off-canvas--top fade'

  @stageModals = =>
    stageModals(@, @modals).then =>
      # Remove Modal and slect2 dropdown if lingering
      @$('#addGeonameModal').remove()
      $('.select2-dropdown').remove()
      # Remove staged class so modal exits vertically
      setTimeout =>
        $(@modals.previousModal.element).removeClass('staged-left')
      , 500


Template.addGeonameModal.onRendered ->
  $('#addGeonameModal').on 'hide.bs.modal', (event) =>
    event.preventDefault()
    $modal = $(event.currentTarget)
    if not $modal.hasClass('out')
      @stageModals()

Template.addGeonameModal.helpers
  latLon: ->
    Template.instance().latLon
  parentLocation: ->
    Template.instance().parentLocation

Template.addGeonameModal.events
  'submit #addGeonameModal': (event, instance)->
    event.preventDefault()
    name = instance.$('#name').val()
    parent = instance.parentLocation.get()[0].item
    [latitude, longitude] = instance.latLon.get()
    geoname =
      id: "eidr:#{name}#{moment().format('Y-MM-DD')}"
      name: name
      admin1Code: parent.admin1Code
      admin2Code: parent.admin2Code
      admin3Code: parent.admin3Code
      admin4Code: parent.admin4Code
      admin1Name: parent.admin1Name
      admin2Name: parent.admin2Name
      countryName: parent.countryName
      countryCode: parent.countryCode
      featureClass: 'P'
      featureCode: 'PPL'
      latitude: latitude
      longitude: longitude
    Meteor.call 'addGeoname', geoname, (error)->
      if error
        notify('error', 'There was a problem creating the geoname.')
        return
      instance.onAdded(geoname)
      instance.stageModals()
