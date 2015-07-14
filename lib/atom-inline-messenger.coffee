# { View } = require 'atom'
{CompositeDisposable} = require 'atom'
Message = require './inline-message-view'
Suggestion = require './inline-suggestion-view'

module.exports = Messenger =

  config:
    messagePositioning:
        type: "string"
        default: "Right"
        description: "Position messages below or to the right of the highlighted text"
        enum: ["Below", "Right"]

  testPackageView: null
  modalPanel: null
  subscriptions: null
  messages:[]
  rendered:[]


  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # @subscriptions.add atom.commands.add 'atom-workspace', 'test-package:toggle': => @toggle()

    @cursorMovementSubscription()
    @updateStyle()

    atom.config.observe 'editor.lineHeight', (newValue) =>
      @updateStyle()
      @render()

    atom.config.observe 'editor.fontSize', (newValue) =>
      @updateStyle()
      @render()

    atom.config.observe 'atom-inline-messaging.messagePositioning', (newValue) =>
      @render()


  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @messageView.destroy()

  serialize: ->
    messageViewState: @messageView.serialize()


  cursorMovementSubscription: () ->
    activeEditor = atom.workspace.getActiveTextEditor()

    activeEditor.onDidChangeCursorPosition (event) =>
      found = activeEditor.findMarkers({
                        inlineMsg:true, 
                        containsBufferPosition:event["newBufferPosition"]
                    })
      if found.length != 0
        @render()

  clear: ->
    @rendered.map (renderedMsg) ->
      renderedMsg.message.destroy()
      renderedMsg.highlight.destroy()
      renderedMsg.gutter.destroy()


  render: ->
    @clear()
    activeEditor = atom.workspace.getActiveTextEditor()
    cursorBufferPosition = activeEditor.getCursorBufferPosition()


    @rendered = @messages.map (msg) =>
    
      mark = activeEditor.markBufferRange(msg.range, {invalidate: 'never', inlineMsg: true})

      selected = mark.getBufferRange().containsPoint(cursorBufferPosition)
      selectedClass = ""
      if selected 
        selectedClass = " is-selected"

      anchor = mark
      gutterAnchor = activeEditor.markBufferRange(@firstLineFirstColOfRange(msg.range), {invalidate: 'never'})
      longestLine = @longestLineInMarker(activeEditor, mark)

      positioning = atom.config.get('atom-inline-messaging.messagePositioning')
      if positioning == "Below"
        anchorRange = [msg.range[0].slice(), msg.range[1].slice()]

        # set line to last line in selection
        anchorRange[0][0] = anchorRange[1][0]
        # and column to 0
        anchorRange[0][1] = 0
        #Set the second part of the selecto to the same place
        anchorRange[1] = anchorRange[0].slice()
        anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})

      else if positioning == "Right"
        anchorRange = [msg.range[0].slice(), msg.range[1].slice()]
        anchorRange[0][0] = anchorRange[0][0]+longestLine
        anchorRange[0][1] = 80
        anchorRange[1] = anchorRange[0].slice()
        anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})

      bubble = activeEditor.decorateMarker(
        anchor
        {
          type: 'overlay',
          class: 'inline-message'
          item: @renderElement(msg, selected, longestLine)
        }
      )
      highlight = activeEditor.decorateMarker(
        mark
        {
          type: 'highlight',
          class: "inline-message-selection-highlight#{selectedClass} severity-#{msg.severity}"
        }
      )
      gutter = activeEditor.decorateMarker(
        gutterAnchor
        {
          type: 'line-number',
          class: "inline-message-gutter severity-#{msg.severity}" 
        }
      )

      return { 
          message: bubble,
          highlight: highlight, 
          gutter: gutter
      }


  renderElement: (element, selected, lineAdjustment) ->
    if element.type == 'message'
      return @renderMessage(element, selected, lineAdjustment)
    else if element.type == 'suggestion'
      return @renderSuggestion(element, selected, lineAdjustment)


  renderMessage: (msg, selected, lineAdjustment) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-message'
    bubble.classList.add('inline-message')
    bubble.classList.add("style-#{msg.style}")
    positioning = atom.config.get('atom-inline-messaging.messagePositioning')
    
    if positioning == "Below"
      bubble.classList.add("is-below")
    else if positioning == "Right"
      bubble.classList.add("is-right")
      bubble.classList.add("up-#{lineAdjustment}")

    if selected == true
      bubble.classList.add("is-selected")

    bubble.appendChild Message.fromMsg(msg)
    bubble


  renderSuggestion: (msg, selected, lineAdjustment) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-suggestion'
    bubble.classList.add('inline-message')
    positioning = atom.config.get('atom-inline-messaging.messagePositioning')
    if positioning == "Below"
      bubble.classList.add("is-below")
    else if positioning == "Right"
      bubble.classList.add("is-right")
      bubble.classList.add("up-#{lineAdjustment}")

    if selected == true
      bubble.classList.add("is-selected")

    bubble.appendChild Suggestion.fromSuggestion(msg)
    bubble



  updateStyle: () ->

    lineHeightEm = atom.config.get("editor.lineHeight")
    fontSizePx = atom.config.get("editor.fontSize")
    lineHeight = lineHeightEm * fontSizePx

    styleList = ("atom-overlay .inline-message.is-right.up-#{n}{ top:#{(n+1)*lineHeight*-1}px; }" for n in [0..80])
    stylesheet = styleList.join("\n")
    ss = atom.styles.addStyleSheet(stylesheet)


  # Return a range that is only the first line and first column
  # of the range given
  firstLineFirstColOfRange: (range) ->
    gutterAnchorRange = [range[0].slice(), range[1].slice()]
    gutterAnchorRange[0][1] = 0
    gutterAnchorRange[1][0] = gutterAnchorRange[0][0]
    gutterAnchorRange[1][1] = 0
    return gutterAnchorRange

  longestLineInMarker: (activeEditor, marker) ->
    screenRange = marker.getScreenRange()
    longestLineRowOffset = 0
    longestLineLength = 0
    offset = 0
    for row in [screenRange.start.row..screenRange.end.row]
      currentRowLength = activeEditor.lineTextForScreenRow(row).length
      if longestLineLength < currentRowLength
        longestLineLength = currentRowLength
        longestLineRowOffset = offset
      offset = offset + 1
    longestLineRowOffset


  message: ({start, end, content, style, severity}) ->
    @messages.push
      type: 'message'
      range: [start, end]
      content: content
      style: style
      severity: severity
    @render()


  suggest: ({start, end, message, suggestedCode, style}) ->
    @messages.push
      type: 'suggestion'
      range: [start, end]
      message: message
      suggestedCode: suggestedCode
      style: style
      severity: "suggestion"
    @render()

    # TextBuffer.setTextInRange(range, text)

  provideInlineMessenger: () ->
    message: @message.bind(this)
    suggest: @suggest.bind(this)
    clear: @clear.bind(this)








