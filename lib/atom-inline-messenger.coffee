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
  focus: null

  activeEditor: null

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:accept-suggestion': (event) =>
        @acceptSuggestion()

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:next-message': (event) =>
        @nextMessage()

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:prev-message': (event) =>
        @prevMessage()

    @activeEditor = atom.workspace.getActiveTextEditor()
    @subscriptions.add @cursorMovementSubscription()
    @updateStyle()

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem (item) =>
      @activeEditor = atom.workspace.getActiveTextEditor()
      @subscriptions.add @cursorMovementSubscription()

    @subscriptions.add atom.config.observe 'editor.lineHeight', (newValue) =>
      @updateStyle()

    @subscriptions.add atom.config.observe 'editor.fontSize', (newValue) =>
      @updateStyle()

    @subscriptions.add atom.config.observe 'atom-inline-messaging.messagePositioning', (newValue) =>
      @refresh()


  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    messageViewState: @messageView.serialize()


  cursorMovementSubscription: () ->
    if @activeEditor
      @activeEditor.onDidChangeCursorPosition (cursor) =>
        for msg in @messages
          if msg.highlight.getMarker().getBufferRange().containsPoint(cursor["newBufferPosition"])
            @refresh()
            break


  clear: ->
    @messages.map (msg) -> msg.destroy()
    

  refresh: ->
    @focus = null
    @messages = @removeDestroyed(@messages)
    @messages.map (msg) => @updateMessage(msg)


  removeDestroyed: (messages) ->
    return (msg for msg in messages when msg.destroyed isnt true)


  select: (msg) ->
    @activeEditor.setCursorBufferPosition(msg.highlight.getMarker().getBufferRange().start)
    msg.update({'selected':true})

  updateMessage:(msg) ->
    update = {}
    cursorBuffPos = @activeEditor.getCursorBufferPosition()

    if msg.highlight.getMarker().getBufferRange().containsPoint(cursorBuffPos)
      update.selected = true
      # if msg.type == 'suggestion'
      @focus = msg
    else
      update.selected = false
    update.positioning = atom.config.get('atom-inline-messaging.messagePositioning').toLowerCase()
    msg.update(update)


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


  animateReplacementBlink: (range) ->
    marker = @activeEditor.markBufferRange(range, {invalidate: 'never', inlineReplacementFlash: true})
    flash = @activeEditor.decorateMarker(
        marker
        {
          type: 'highlight',
          class: 'inline-replacement-flash'
        }
      )
    setNewClass = ->
      flash.setProperties({
                  type: 'highlight',
                  class: 'inline-replacement-flash flash-on'
                })
    setTimeout setNewClass, 50
    setTimeout flash.destroy, 700


  nextMessage: () ->
    if @messages.length == 0
      return
    if @focus is null
      # Find the first message after the cursor
      cursorBuffPos = @activeEditor.getCursorBufferPosition()
      for msg in @messages
        range = msg.getRange()
        if range.start.row >= cursorBuffPos.row
          @select(msg)
          return
    else
      stopAtNext = false
      for msg in @messages
        if stopAtNext is true
          @select(msg)
          return
        if msg.selected is true
          stopAtNext = true
    # If nothing, select the first message
    @select(@messages[0])


  prevMessage: () ->
    stopAtNext = false
    for msg in @messages.slice(0).reverse()
      if stopAtNext is true
        @select(msg)
        return
      if msg.selected is true
        stopAtNext = true
    @select(@messages[@messages.length - 1])


  acceptSuggestion: () ->
    if @focus is null
      return

    if @focus.type == 'suggestion'
      newText = @focus.suggestion
      range = @focus.range

      activeBuffer = @activeEditor.getBuffer()
      newRange = activeBuffer.setTextInRange(range, newText)

      @focus.destroy()
      @animateReplacementBlink(newRange)


  provideInlineMessenger: () ->
    message: @message.bind(this)
    suggest: @suggest.bind(this)









