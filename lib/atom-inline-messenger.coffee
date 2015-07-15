# { View } = require 'atom'
{CompositeDisposable} = require 'atom'
Message = require './inline-message-view'
Suggestion = require './inline-suggestion-view'

module.exports = Messenger =

  config:
    messagePositioning:
        type: "string"
        default: "Right"
        description: "Position multiline messages below or to the right of the highlighted text"
        enum: ["Below", "Right"]

    showKeyboardShortcuts:
        type: "boolean"
        default: true
        description: "Show keyboard shortcut reminder at the bottom of a suggestion/message."


  subscriptions: null
  messages:[]
  currentSuggestion: null


  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # @subscriptions.add atom.commands.add 'atom-workspace', 'test-package:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:accept-suggestion': (event) =>
        @acceptSuggestion()

    @cursorMovementSubscription()
    @updateStyle()

    @subscriptions.add atom.config.observe 'editor.lineHeight', (newValue) =>
      @updateStyle()
      @render()

    @subscriptions.add atom.config.observe 'editor.fontSize', (newValue) =>
      @updateStyle()
      @render()

     @subscriptions.add atom.config.observe 'atom-inline-messaging.messagePositioning', (newValue) =>
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
    @messages.map (msg) ->
      if 'rendered' of msg
        msg.rendered.message.destroy()
        msg.rendered.highlight.destroy()
        # msg.rendered.highlightLeft.destroy()
        # msg.rendered.gutterIcon.destroy()
        # msg.rendered.gutter.destroy()


  render: ->
    @clear()
    activeEditor = atom.workspace.getActiveTextEditor()
    cursorBufferPosition = activeEditor.getCursorBufferPosition()
    @currentSuggestion = null

    @messages = @messages.map (msg) =>
    
      smallSnippet = false
      if msg.range[0][0] == msg.range[1][0]
        smallSnippet = true

      mark = activeEditor.markBufferRange(msg.range, {invalidate: 'never', inlineMsg: true})

      selected = mark.getBufferRange().containsPoint(cursorBufferPosition)
      selectedClass = ""
      if selected 
        selectedClass = "-is-selected"
        msg.selected = true
      else
        msg.selected = false

      if selected and msg.type == 'suggestion'
        @currentSuggestion = msg

      anchor = mark
      gutterAnchor = activeEditor.markBufferRange(@firstLineFirstColOfRange(msg.range), {invalidate: 'never'})
      longestLineOffset = @longestLineInMarker(activeEditor, mark)

      positioning = atom.config.get('atom-inline-messaging.messagePositioning')

      if positioning == 'Below' or smallSnippet is true
        anchorRange = [msg.range[0].slice(), msg.range[1].slice()]

        # and column to 0
        if smallSnippet is true
          anchorRange[0][1] = anchorRange[0][1] + 1
        else
           # set line to last line in selection
          anchorRange[0][0] = anchorRange[1][0]
          anchorRange[0][1] = 1

        #Set the end of the selection to the same place
        anchorRange[1] = anchorRange[0].slice()
        anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
        msg.positioning = "below"

      else if positioning == "Right"
        anchorRange = [msg.range[0].slice(), msg.range[1].slice()]
        anchorRange[0][0] = anchorRange[0][0] + longestLineOffset
        anchorRange[0][1] = 250
        anchorRange[1] = anchorRange[0].slice()
        anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
        msg.positioning = "right"
        msg.lineOffsetFromTop = longestLineOffset

      smallSnippetClass = ""
      if smallSnippet is true
        smallSnippetClass = " is-small-snippet"


      bubble = activeEditor.decorateMarker(
        anchor
        {
          type: 'overlay',
          class: 'inline-message'
          item: @renderElement(msg)
        }
      )

     
      if smallSnippet is true
        if selected 
          selectedClass = " is-selected"
        highlight = activeEditor.decorateMarker(
          mark
          {
            type: 'highlight',
            class: "inline-message-selection-highlight#{selectedClass} severity-#{msg.severity}#{smallSnippetClass}"
          }
        )
      else
        # The class name mangling is because atom wont accept multiple classes for a line decoration
        # Not that big of a deal, I suppose
        highlight = activeEditor.decorateMarker(
          mark
          {
            type: 'line',
            class: "inline-message-multiline-highlight-severity-#{msg.severity}#{selectedClass}"
          }
        )


       
      # gutter = activeEditor.decorateMarker(
      #   mark
      #   {
      #     type: 'line-number',
      #     class: "inline-message-gutter-multiline severity-#{msg.severity}" 
      #   }
      # )
      # gutterIcon = activeEditor.decorateMarker(
      #   gutterAnchor
      #   {
      #     type: 'line-number',
      #     class: "inline-message-gutter severity-#{msg.severity}" 
      #   }
      # )


      msg['rendered'] =
                  message: bubble,
                  # highlight: highlight, 
                  highlight: highlight,
                  # gutter: gutter,
                  # gutterIcon: gutterIcon

      msg
      


  renderElement: (element) ->
    if element.type == 'message'
      return @renderMessage(element)
    else if element.type == 'suggestion'
      return @renderSuggestion(element)


  renderMessage: (msg) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-message'
    bubble.classList.add('inline-message')
    # positioning = atom.config.get('atom-inline-messaging.messagePositioning')
    
    if msg.positioning == "below"
      bubble.classList.add("is-below")
    else if msg.positioning == "right"
      bubble.classList.add("is-right")
      bubble.classList.add("up-#{msg.lineOffsetFromTop}")

    if msg.selected is true
      bubble.classList.add("is-selected")

    bubble.appendChild Message.fromMsg(msg)
    bubble


  renderSuggestion: (msg) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-suggestion'
    bubble.classList.add('inline-message')
    # positioning = atom.config.get('atom-inline-messaging.messagePositioning')
    if msg.positioning == "below"
      bubble.classList.add("is-below")
    else if msg.positioning == "right"
      bubble.classList.add("is-right")
      bubble.classList.add("up-#{msg.lineOffsetFromTop}")

    if msg.selected is true
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
      severity: severity
    @render()


  suggest: ({start, end, message, suggestedCode}) ->
    @messages.push
      type: 'suggestion'
      range: [start, end]
      message: message
      suggestedCode: suggestedCode
      severity: "suggestion"
    @render()

  # Accepts the current suggestion
  acceptSuggestion: () ->
    if @currentSuggestion is null
      return

    newText = @currentSuggestion.suggestedCode
    range = @currentSuggestion.range

    activeBuffer = atom.workspace.getActiveTextEditor().getBuffer()
    activeBuffer.setTextInRange(range, newText)




  provideInlineMessenger: () ->
    message: @message.bind(this)
    suggest: @suggest.bind(this)
    clear: @clear.bind(this)








