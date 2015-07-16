
MessageView = require './inline-message-view'
Suggestion = require './inline-suggestion-view'

class Message
  constructor: ({editor, type, range, text, severity, badge, positioning, suggestion}) ->
    @editor = editor 
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
    @render()


  render: () ->
    if @editor is null or @editor == ''
      return

    mark = @editor.markBufferRange(@range, {invalidate: 'never', inlineMsg: true})
    anchor = mark

    if @positioning == 'below'
      anchorRange = [@range[0].slice(), @range[1].slice()]

      # and column to 0
      if @smallSnippet is true
        anchorRange[0][1] = anchorRange[0][1] + 1
      else
         # set line to last line in selection
        anchorRange[0][0] = anchorRange[1][0]
        anchorRange[0][1] = 1

      #Set the end of the selection to the same place
      anchorRange[1] = anchorRange[0].slice()
      anchor = @editor.markBufferRange(anchorRange, {invalidate: 'never'})

    else if @positioning == "right"
      @offsetFromTop = @longestLineInMarker(mark)
      anchorRange = [@range[0].slice(), @range[1].slice()]
      anchorRange[0][0] = anchorRange[0][0] + @offsetFromTop
      anchorRange[0][1] = 250
      anchorRange[1] = anchorRange[0].slice()
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

  updateEditor: (editor) ->
    @editor = editor
    @render()

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

  setPositioning: (pos) ->
    if @smallSnippet is true
      @positioning = 'below'
    else if @positioning != pos
      @positioning = pos

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