import { formatLocation } from '/imports/utils'
import GeonameSchema from '/imports/schemas/geoname.coffee'
import { stageModals } from '/imports/ui/modals'

Template.locationSelect2.helpers
  locationsOptionsFn: ->
    (params, callback) ->
      if not params.term
        callback results: []
        return
      Meteor.call 'searchGeonames', params.term, (error, result) ->
        if error
          console.error error
          return
        callback results: result.data.hits.map (hit) ->
          { id, latitude, longitude } = hit._source
          # Ensure numeric lat/lng
          hit._source.latitude = parseFloat(latitude)
          hit._source.longitude = parseFloat(longitude)
          id: id
          text: formatLocation(hit._source)
          item: GeonameSchema.clean(hit._source)

  controlTemplate: ->
    if Template.instance().data.allowAdd 
      Template.addLocationControl

Template.addLocationControl.events
  'click button': (event, instance) ->
    parentInstance = instance.data.parentInstance
    stageModals parentInstance,
      currentModal:
        element: parentInstance.data.parentModal
        remove: 'off-canvas--top fade'
        add: 'staged-left'
    parentInstance.$('select').select2('close')
    Modal.show 'addGeonameModal',
      parentModal: parentInstance.data.parentModal
      onAdded: (value)->
        parentInstance.values.set parentInstance.values.get().concat
          id: value.id
          text: value.name
          item: value
