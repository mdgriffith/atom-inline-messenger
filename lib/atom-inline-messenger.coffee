# { View } = require 'atom'
{CompositeDisposable} = require 'atom'
# MessageView = require './inline-message-view'
# Suggestion = require './inline-suggestion-view'

Message = require './message-model'

module.exports = Messenger =

  config:
    messagePositioning:
        type: "string"
        default: "Right"
        description: "Position multiline messages below or to the right of the highlighted text"
        enum: ["Below", "Right"]

    showKeyboardShortcutForSuggestion:
        type: "boolean"
        default: true
        description: "Show keyboard shortcut reminder at the bottom of a suggestion."


  subscriptions: null
  messages:[]
  currentSuggestion: null

  activeEditor: null

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # @subscriptions.add atom.commands.add 'atom-workspace', 'test-package:toggle': => @toggle()
    atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:accept-suggestion': (event) =>
        @acceptSuggestion()

    @activeEditor = atom.workspace.getActiveTextEditor()
    @subscriptions.add @cursorMovementSubscription()

    # @subscriptions.add @cursorMovementSubscription()
    @updateStyle()

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem (item) =>
      @activeEditor = atom.workspace.getActiveTextEditor()
      @subscriptions.add @cursorMovementSubscription()

    @subscriptions.add atom.config.observe 'editor.lineHeight', (newValue) =>
      @updateStyle()
      # @refresh()

    @subscriptions.add atom.config.observe 'editor.fontSize', (newValue) =>
      @updateStyle()
      # @refresh()

    @subscriptions.add atom.config.observe 'atom-inline-messaging.messagePositioning', (newValue) =>
      @refresh()


  deactivate: ->
    @subscriptions.dispose()
    @messageView.destroy()


  serialize: ->
    messageViewState: @messageView.serialize()


  cursorMovementSubscription: () ->
    if @activeEditor
      @activeEditor.onDidChangeCursorPosition (cursor) =>
        for msg in @messages
          if msg.highlight.getMarker().getBufferRange().containsPoint(cursor["newBufferPosition"])
            @refresh()
            break
          # if 'rendered' of msg
          #   buffRange = msg.rendered.highlight.getMarker().getBufferRange()
          #   if buffRange.containsPoint(event["newBufferPosition"])
          #     @refresh()
          #     break


  clear: ->
    @messages.map (msg) -> msg.destroy()
    

  refresh: ->
    # @clear()
    @currentSuggestion = null

    @messages = @removeDestroyed(@messages)

    # console.log @messages
    @messages.map (msg) => @updateMessage(msg)


  removeDestroyed: (messages) ->
    # messages
    return (msg for msg in messages when msg.destroyed isnt true)


  # render:(msg) ->
  #   if @activeEditor is null or @activeEditor == ''
  #     return msg
  #   # @clear()
  #   # activeEditor = atom.workspace.getActiveTextEditor()
  #   cursorBufferPosition = @activeEditor.getCursorBufferPosition()
  #   smallSnippet = false
  #   if msg.range[0][0] == msg.range[1][0]
  #     smallSnippet = true

  #   mark = @activeEditor.markBufferRange(msg.range, {invalidate: 'never', inlineMsg: true})

  #   selected = mark.getBufferRange().containsPoint(cursorBufferPosition)
  #   selectedClass = ""
  #   if selected 
  #     selectedClass = "-is-selected"
  #     msg.selected = true
  #   else
  #     msg.selected = false

  #   if selected and msg.type == 'suggestion'
  #     @currentSuggestion = msg

  #   anchor = mark
  #   longestLineOffset = @longestLineInMarker(mark)

  #   positioning = atom.config.get('atom-inline-messaging.messagePositioning')

  #   if positioning == 'Below' or smallSnippet is true
  #     anchorRange = [msg.range[0].slice(), msg.range[1].slice()]

  #     # and column to 0
  #     if smallSnippet is true
  #       anchorRange[0][1] = anchorRange[0][1] + 1
  #     else
  #        # set line to last line in selection
  #       anchorRange[0][0] = anchorRange[1][0]
  #       anchorRange[0][1] = 1

  #     #Set the end of the selection to the same place
  #     anchorRange[1] = anchorRange[0].slice()
  #     anchor = @activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
  #     msg.positioning = "below"

  #   else if positioning == "Right"
  #     anchorRange = [msg.range[0].slice(), msg.range[1].slice()]
  #     anchorRange[0][0] = anchorRange[0][0] + longestLineOffset
  #     anchorRange[0][1] = 250
  #     anchorRange[1] = anchorRange[0].slice()
  #     anchor = @activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
  #     msg.positioning = "right"
  #     msg.lineOffsetFromTop = longestLineOffset

  #   smallSnippetClass = ""
  #   if smallSnippet is true
  #     smallSnippetClass = " is-small-snippet"

  #   message = @activeEditor.decorateMarker(
  #     anchor
  #     {
  #       type: 'overlay',
  #       class: 'inline-message'
  #       item: @renderElement(msg)
  #     }
  #   )

  #   if smallSnippet is true
  #     if selected 
  #       selectedClass = " is-selected"
  #     highlight = @activeEditor.decorateMarker(
  #       mark
  #       {
  #         type: 'highlight',
  #         class: "inline-message-selection-highlight#{selectedClass} severity-#{msg.severity}#{smallSnippetClass}"
  #       }
  #     )
  #   else
  #     # The class name mangling is because atom wont accept multiple classes for a line decoration
  #     # Not that big of a deal, I suppose
  #     highlight = @activeEditor.decorateMarker(
  #       mark
  #       {
  #         type: 'line',
  #         class: "inline-message-multiline-highlight-severity-#{msg.severity}#{selectedClass}"
  #       }
  #     )

  #   msg['rendered'] =
  #           message: message,
  #           highlight: highlight

  #   msg.destroy = (preventRefresh=false) =>
  #     if 'rendered' of msg
  #       msg.rendered.message.destroy()
  #       msg.rendered.highlight.destroy()
  #       msg.destroyed = true
  #     if preventRefresh isnt true
  #       @refresh()
  #   msg

  updateMessage:(msg) ->
    update = {}
    cursorBuffPos = @activeEditor.getCursorBufferPosition()

    if msg.highlight.getMarker().getBufferRange().containsPoint(cursorBuffPos)
      update.selected = true
    else
      update.selected = false
    update.positioning = atom.config.get('atom-inline-messaging.messagePositioning').toLowerCase()
    msg.update(update)


  # renderDEP:(msg) ->
  #   if @activeEditor is null or @activeEditor == ''
  #     return msg
  #   # @clear()
  #   # activeEditor = atom.workspace.getActiveTextEditor()
  #   cursorBufferPosition = @activeEditor.getCursorBufferPosition()
  #   smallSnippet = false
  #   if msg.range[0][0] == msg.range[1][0]
  #     smallSnippet = true

  #   mark = @activeEditor.markBufferRange(msg.range, {invalidate: 'never', inlineMsg: true})

  #   selected = mark.getBufferRange().containsPoint(cursorBufferPosition)
  #   selectedClass = ""
  #   if selected 
  #     selectedClass = "-is-selected"
  #     msg.selected = true
  #   else
  #     msg.selected = false

  #   if selected and msg.type == 'suggestion'
  #     @currentSuggestion = msg

  #   anchor = mark
  #   longestLineOffset = @longestLineInMarker(mark)

  #   positioning = atom.config.get('atom-inline-messaging.messagePositioning')

  #   if positioning == 'Below' or smallSnippet is true
  #     anchorRange = [msg.range[0].slice(), msg.range[1].slice()]

  #     # and column to 0
  #     if smallSnippet is true
  #       anchorRange[0][1] = anchorRange[0][1] + 1
  #     else
  #        # set line to last line in selection
  #       anchorRange[0][0] = anchorRange[1][0]
  #       anchorRange[0][1] = 1

  #     #Set the end of the selection to the same place
  #     anchorRange[1] = anchorRange[0].slice()
  #     anchor = @activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
  #     msg.positioning = "below"

  #   else if positioning == "Right"
  #     anchorRange = [msg.range[0].slice(), msg.range[1].slice()]
  #     anchorRange[0][0] = anchorRange[0][0] + longestLineOffset
  #     anchorRange[0][1] = 250
  #     anchorRange[1] = anchorRange[0].slice()
  #     anchor = @activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
  #     msg.positioning = "right"
  #     msg.lineOffsetFromTop = longestLineOffset

  #   smallSnippetClass = ""
  #   if smallSnippet is true
  #     smallSnippetClass = " is-small-snippet"

  #   message = @activeEditor.decorateMarker(
  #     anchor
  #     {
  #       type: 'overlay',
  #       class: 'inline-message'
  #       item: @renderElement(msg)
  #     }
  #   )

  #   if smallSnippet is true
  #     if selected 
  #       selectedClass = " is-selected"
  #     highlight = @activeEditor.decorateMarker(
  #       mark
  #       {
  #         type: 'highlight',
  #         class: "inline-message-selection-highlight#{selectedClass} severity-#{msg.severity}#{smallSnippetClass}"
  #       }
  #     )
  #   else
  #     # The class name mangling is because atom wont accept multiple classes for a line decoration
  #     # Not that big of a deal, I suppose
  #     highlight = @activeEditor.decorateMarker(
  #       mark
  #       {
  #         type: 'line',
  #         class: "inline-message-multiline-highlight-severity-#{msg.severity}#{selectedClass}"
  #       }
  #     )

  #   msg['rendered'] =
  #           message: message,
  #           highlight: highlight

  #   msg.destroy = (preventRefresh=false) =>
  #     if 'rendered' of msg
  #       msg.rendered.message.destroy()
  #       msg.rendered.highlight.destroy()
  #       msg.destroyed = true
  #     if preventRefresh isnt true
  #       @refresh()
  #   msg
  


  updateStyle: () ->
    lineHeightEm = atom.config.get("editor.lineHeight")
    fontSizePx = atom.config.get("editor.fontSize")
    lineHeight = lineHeightEm * fontSizePx

    styleList = ("atom-overlay .inline-message.is-right.up-#{n}{ top:#{(n+1)*lineHeight*-1}px; }" for n in [0..250])
    stylesheet = styleList.join("\n")
    ss = atom.styles.addStyleSheet(stylesheet)



  message: ({start, end, text, severity, badge}) ->
    msg = new Message
            editor: @activeEditor 
            type: 'message'
            range: [start, end]
            positioning: atom.config.get('atom-inline-messaging.messagePositioning').toLowerCase()
            text: text
            severity: severity
            badge: badge
    @messages.push msg
  


  suggest: ({start, end, text, suggestedCode, badge}) ->
    msg = new Message
            editor: @activeEditor 
            type: 'suggestion'
            range: [start, end]
            positioning: atom.config.get('atom-inline-messaging.messagePositioning').toLowerCase()
            text: text
            severity: 'suggestion'
            badge: badge

            suggestion: suggestedCode

    @messages.push msg


  # Accepts the current suggestion
  acceptSuggestion: () ->
    if @currentSuggestion is null
      return

    newText = @currentSuggestion.suggestedCode
    range = @currentSuggestion.range

    activeBuffer = @activeEditor.getBuffer()
    activeBuffer.setTextInRange(range, newText)

    @currentSuggestion.destroy()


  provideInlineMessenger: () ->
    message: @message.bind(this)
    suggest: @suggest.bind(this)
    clear: @clear.bind(this)








