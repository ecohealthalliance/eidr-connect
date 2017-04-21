import { annotateContent } from '/imports/ui/annotation'

export getIncidentSnippet = (content, incident, paddingCharaters=50) ->
  textOffsets = incident.annotations.case[0].textOffsets
  annotation = [
    type: 'case'
    textOffsets: textOffsets
  ]
  startingIndex = textOffsets[0]
  startingIndex = Math.max(startingIndex - paddingCharaters, 0)
  endingIndex = textOffsets[1]
  endingIndex = Math.min(endingIndex + paddingCharaters, content.length - 1)
  annotateContent content, annotation,
    startingIndex: startingIndex
    endingIndex: endingIndex
    pointerEvents: false
