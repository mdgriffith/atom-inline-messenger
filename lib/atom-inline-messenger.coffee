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


  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'test-package:toggle': => @toggle()

    atom.config.observe 'atom-inline-messaging.messagePositioning', (newValue) =>
      # `observe` calls immediately and every time the value is changed 
      @render()
      # console.log 'My configuration changed:', newValue


  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @messageView.destroy()

  serialize: ->
    messageViewState: @messageView.serialize()

  longestLineInMarker: (activeEditor, marker) ->
    screenRange = marker.getScreenRange()

    longestLineRowOffset = 0
    longestLineLength = 0
    offset = 0

    console.log "start: " +screenRange.start.row
    console.log "end: " + screenRange.end.row

    for row in [screenRange.start.row..screenRange.end.row]
      console.log "counting" + row
      currentRowLength = activeEditor.lineTextForScreenRow(row).length
      if longestLineLength < currentRowLength
        longestLineLength = currentRowLength
        longestLineRowOffset = offset
      offset = offset + 1

    console.log "longest line offest #{longestLineRowOffset}"
    longestLineRowOffset

  render: ->
    activeEditor = atom.workspace.getActiveTextEditor()
    for msg in @messages

      mark = activeEditor.markBufferRange(msg.range, {invalidate: 'never'})
      anchor = mark

      longestLine = @longestLineInMarker(activeEditor, mark)
      console.log longestLine

      positioning = atom.config.get('atom-inline-messaging.messagePositioning')
      if positioning == "Below"
        # msgClassList.push("is-below")
        anchorRange = [msg.range[0].slice(), msg.range[1].slice()]

        # set line to last line in selection
        anchorRange[0][0] = anchorRange[1][0]
        # and column to 0
        anchorRange[0][1] = 0
        #Set the second part of the selecto to the same place
        anchorRange[1] = anchorRange[0].slice()
        anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})

      else if positioning == "Right"
        # msgClassList.push("is-right")
        anchorRange = [msg.range[0].slice(), msg.range[1].slice()]
        anchorRange[0][0] = anchorRange[0][0]+longestLine
        anchorRange[0][1] = 80
        anchorRange[1] = anchorRange[0].slice()
        anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})

      bubble = activeEditor.decorateMarker(
        anchor
        {
          type: 'overlay',
          item: @renderElement(msg, longestLine)
        }
      )
      highlight = activeEditor.decorateMarker(
        mark
        {
          type: 'highlight',
          class: 'inline-message-selection-highlight'
        }
      )
      lineheight = highlight.displayBuffer.lineHeightInPixels


  renderElement: (element, lineAdjustment) ->
    if element.type == 'message'
      return @renderMessage(element, lineAdjustment)
    else if element.type == 'suggestion'
      return @renderSuggestion(element, lineAdjustment)

  renderMessage: (msg, lineAdjustment) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-message'
    bubble.classList.add("style-" + msg.style)
    positioning = atom.config.get('atom-inline-messaging.messagePositioning')
    
    if positioning == "Below"
      bubble.classList.add("is-below")
    else if positioning == "Right"
      bubble.classList.add("is-right")
      bubble.classList.add("up-#{lineAdjustment}")


    bubble.appendChild Message.fromMsg(msg)
    bubble

  renderSuggestion: (msg, lineAdjustment) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-suggestion'
    positioning = atom.config.get('atom-inline-messaging.messagePositioning')
    if positioning == "Below"
      bubble.classList.add("is-below")
    else if positioning == "Right"
      bubble.classList.add("is-right")
      bubble.classList.add("up-#{lineAdjustment}")
    bubble.appendChild Suggestion.fromSuggestion(msg)
    bubble

  message: ({start, end, content, style}) ->
    @messages.push
      type: 'message'
      range: [start, end]
      content: content
      style: style
    @render()

  suggest: ({start, end, message, suggestedCode, style}) ->
    @messages.push
      type: 'suggestion'
      range: [start, end]
      message: message
      suggestedCode: suggestedCode
      style: style
    @render()

    # TextBuffer.setTextInRange(range, text)

  provideInlineMessenger: () ->
    message: @message.bind(this)
    suggest: @suggest.bind(this)
    clear: -> console.log "clear"




