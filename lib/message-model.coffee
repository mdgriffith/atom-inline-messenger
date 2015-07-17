
MessageView = require './inline-message-view'


class Message
  constructor: ({editor, type, range, text, severity, badge, positioning, debug, suggestion, showShortcuts}) ->
    @editor = editor 
    @debug = debug
    @type = type
    # @range = range
    @smallSnippet = range[0][0] == range[1][0]
    @text = text
    @suggestion = suggestion
    @severity = severity
    @badge = badge
    @destroyed = false
    @selected = false
    @offsetFromTop = 0
    @highlight = null
    @messageBubble = null
    @correctIndentation = false
    @showShortcuts = showShortcuts
    @indentLevel = 0
    
    
    if @editor is null or @editor == ''
      return

    
    mark = @editor.markBufferRange(range, {invalidate: 'never', inlineMsg: true})
    @offsetFromTop = @longestLineInMarker(mark)
    @positioning =  @setPositioning(positioning, mark.getBufferRange())
    anchorRange = @calculateAnchorRange(mark)
    anchor = @editor.markBufferRange(anchorRange, {invalidate: 'never'})
    
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
    
    @correctIndentation = @requiresIndentCorrection()
    @correctLastLine = @requiresLastLineCorrection()
 
    @messageBubble = @editor.decorateMarker(
      anchor
      {
        type: 'overlay',
        class: 'inline-message'
        item: MessageView.fromMsg(this)
      }
    )
    if @debug is true
      @updateDebugText()

    mark.onDidChange => @updateMarkerPosition()

  requiresIndentCorrection: ->
    range = @getRange()
    @indentLevel = @editor.indentationForBufferRow(range.start.row)
    lineLength = @editor.lineTextForScreenRow(range.end.row).length
    rowSpan = Math.abs(range.end.row - range.start.row)
    return @indentLevel >= 1 or (rowSpan == 0 and lineLength == 0)

  requiresLastLineCorrection: ->
    range = @getRange()
    lineLength = @editor.lineTextForScreenRow(range.end.row).length
    rowSpan = Math.abs(range.end.row - range.start.row)
    return lineLength == 0 and rowSpan != 0


  debugText: ->
    text = []
    text.push "type: #{@type}"
    text.push "severity: #{@severity}"
    text.push "text: #{@text}"
    text.push "suggestion: #{@suggestion}"
    text.push "positioning: #{@positioning}"
    text.push "offsetFromTop: #{@offsetFromTop}"
    text.push "correctIndentation: #{@correctIndentation}"
    text.push "indentation: #{@indentLevel}"
    text.push "emptyLastLine: #{@correctLastLine}"

    if @highlight isnt null
      hmarker = @highlight.getMarker().getBufferRange()
      text.push "highlight range strt:#{hmarker.start.row} #{hmarker.start.column}"
      text.push "highlight range  end:#{hmarker.end.row} #{hmarker.end.column}"

    if @messageBubble isnt null
      amarker = @messageBubble.getMarker().getBufferRange()
      text.push "anchor range strt:#{amarker.start.row} #{amarker.start.column}"
      text.push "anchor range  end:#{amarker.end.row} #{amarker.end.column}"

    text.join "\n"

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
    anchorRange = @calculateAnchorRange(@highlight.getMarker())
    @messageBubble.getMarker().setBufferRange(anchorRange)


  updateDebugText: ->
    @messageBubble.properties.item.textContent = @debugText()


  calculateAnchorRange: (marker) ->
    range = marker.getBufferRange()
    # copy range
    anchorRange = [[range.start.row,range.start.column], [range.end.row,range.end.column]]
    if @positioning == 'below'
      if @smallSnippet is true
        anchorRange[0][1] = anchorRange[0][1] + 1
      else
         # set line to last line in selection
        anchorRange[0][0] = anchorRange[1][0]
        anchorRange[0][1] = 1
      #Set the end of the selection to the same place
      anchorRange[1] = anchorRange[0].slice()
      # console.log "set Range"
      # console.log anchorRange
    else if @positioning == "right"
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


  setPositioning: (pos, range) ->
   
    if @smallSnippet is true and range.end.row >= @editor.getLastBufferRow() - 2
      @positioning = 'right'
    else if @smallSnippet is true
      @positioning = 'below'
    else if @positioning != pos
      @positioning = pos


  updateMarkerPosition: () ->
    @correctIndentation = @requiresIndentCorrection()
    @correctLastLine = @requiresLastLineCorrection()
    
    if @correctIndentation is true
      @messageBubble.properties.item.classList.add 'indentation-correction'
    else
      @messageBubble.properties.item.classList.remove 'indentation-correction'

    if @correctLastLine is true
      @messageBubble.properties.item.classList.add 'empty-lastline-correction'
    else
      @messageBubble.properties.item.classList.remove 'empty-lastline-correction'

    newOffsetFromTop = @longestLineInMarker(@highlight.getMarker())
    mark = @messageBubble.getMarker()
    if newOffsetFromTop != @offsetFromTop
      @messageBubble.properties.item.classList.remove "up-#{@offsetFromTop}"
      @messageBubble.properties.item.classList.add "up-#{newOffsetFromTop}"
      @offsetFromTop = newOffsetFromTop

    @updateAnchor()

    if @debug is true
      @updateDebugText()


  update: (newData) ->
    requiresRefresh = false
    if 'selected' of newData
      if @selected != newData.selected
        @selected = newData.selected
        requiresRefresh = true

    if 'positioning' of newData
      if @positioning != newData.positioning
        @setPositioning(newData.positioning, @getRange())
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