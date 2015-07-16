
MessageView = require './inline-message-view'
Suggestion = require './inline-suggestion-view'

class Message
  constructor: ({editor, type, range, text, severity, badge, positioning, debug, suggestion}) ->
    @editor = editor 
    @debug = debug
    @type = type
    @range = range
    @smallSnippet = range[0][0] == range[1][0]
    @text = text
    @suggestion = suggestion
    @severity = severity
    @badge = badge
    @destroyed = false
    @selected = false
    @positioning =  @setPositioning(positioning)
    @offsetFromTop = 0
    @highlight = null
    @messageBubble = null
    @correctIndentation = false
    @render()

  requiresIndentCorrection: ->
    return @editor.indentationForBufferRow(@range[0][0]) != 0

  render: ->
    if @editor is null or @editor == ''
      return

    @correctIndentation = @requiresIndentCorrection()
    mark = @editor.markBufferRange(@range, {invalidate: 'never', inlineMsg: true})
    @offsetFromTop = @longestLineInMarker(mark)
    anchor = mark
    mark.onDidChange => @updateMarkerPosition()
    anchorRange = @calculateAnchorRange()
    anchor = @editor.markBufferRange(anchorRange, {invalidate: 'never'})

    @messageBubble = @editor.decorateMarker(
      anchor
      {
        type: 'overlay',
        class: 'inline-message'
        item: @renderElement()
      }
    )

    if @smallSnippet is true
      @highlight = @editor.decorateMarker(
        mark
        {
          type: 'highlight',
          class: @formatHighlightClass()
        }
      )
    else
      @highlight = @editor.decorateMarker(
        mark
        {
          type: 'line',
          class: @formatLineClass()
        }
      )


  formatHighlightClass: () ->
    classList = ["inline-message-selection-highlight"]
    classList.push("severity-#{@severity}")
    if @selected
      classList.push("is-selected")
    if @smallSnippet
      classList.push("is-small-snippet")
    return classList.join ' '


  formatLineClass: () ->
    # The class name mangling is because atom wont accept 
    # multiple classes for a line decoration
    # Not that big of a deal, I suppose
    cls = "inline-message-multiline-highlight"
    cls = cls + "-severity-#{@severity}"
    if @selected
      cls = cls + "-is-selected"
    return cls


  updateAnchor: () ->
    anchorRange = @calculateAnchorRange()
    @messageBubble.getMarker().setBufferRange(anchorRange)


  calculateAnchorRange: () ->
    anchorRange = [@range[0].slice(), @range[1].slice()]
    if @positioning == 'below'
      if @smallSnippet is true
        anchorRange[0][1] = anchorRange[0][1] + 1
      else
         # set line to last line in selection
        anchorRange[0][0] = anchorRange[1][0]
        anchorRange[0][1] = 1
      #Set the end of the selection to the same place
      anchorRange[1] = anchorRange[0].slice()
    else if @positioning == "right"
      anchorRange = [@range[0].slice(), @range[1].slice()]
      anchorRange[0][0] = anchorRange[0][0] + @offsetFromTop
      anchorRange[0][1] = 250
      anchorRange[1] = anchorRange[0].slice()
    return anchorRange


  # Return an relative row offset of which line is longest in a marker.
  # So, if the second line is longest, return 1
  longestLineInMarker: (marker) ->
    screenRange = marker.getScreenRange()
    longestLineRowOffset = 0
    longestLineLength = 0
    offset = 0
    for row in [screenRange.start.row..screenRange.end.row]
      currentRowLength = @editor.lineTextForScreenRow(row).length
      if longestLineLength < currentRowLength
        longestLineLength = currentRowLength
        longestLineRowOffset = offset
      offset = offset + 1
    longestLineRowOffset


  renderElement: () ->
    if @type == 'message'
      return MessageView.fromMsg(this)
    else if @type == 'suggestion'
      return Suggestion.fromSuggestion(this)


  refresh: () ->
    if @selected is true
      @messageBubble.properties.item.classList.add('is-selected')
    else
      @messageBubble.properties.item.classList.remove('is-selected')

    if @smallSnippet is true
      @highlight.setProperties({
                type:'highlight'
                class:@formatHighlightClass()
                  })
    else
      @highlight.setProperties({
        type:'line',
        class:@formatLineClass()})

    if @correctIndentation is true
      @messageBubble.properties.item.classList.add('indentation-correction')
    else
      @messageBubble.properties.item.classList.remove('indentation-correction')


  setPositioning: (pos) ->
    if @smallSnippet is true
      @positioning = 'below'
    else if @positioning != pos
      @positioning = pos


  updateMarkerPosition: () ->
    @correctIndentation = @requiresIndentCorrection()
    @updateAnchor()
    if @correctIndentation is true
      @messageBubble.properties.item.classList.add('indentation-correction')
    else
      @messageBubble.properties.item.classList.remove('indentation-correction')


  update: (newData) ->
    requiresRefresh = false
    if 'selected' of newData
      if @selected != newData.selected
        @selected = newData.selected
        requiresRefresh = true

    if 'positioning' of newData
      if @positioning != newData.positioning
        @setPositioning(newData.positioning)
        requiresRefresh = true

    if requiresRefresh is true
      @refresh()


  getRange: () ->
    @highlight.getMarker().getBufferRange()


  destroy: ->
    @destroyed = true
    if @highlight
      @highlight.destroy()
    if @messageBubble
      @messageBubble.destroy()




module.exports = Message