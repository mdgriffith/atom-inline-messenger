# { View } = require 'atom'
{CompositeDisposable} = require 'atom'
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
      @messages.map (msg) -> msg.update({positioning:newValue.toLowerCase()})


  deactivate: ->
    @subscriptions.dispose()
    @clear()


  serialize: ->
    messageViewState: @messageView.serialize()


  pointDistance: (point1, point2) ->
    return [Math.abs(point1.row-point2.row), Math.abs(point1.column-point2.column)]


  cursorMovementSubscription: () ->
    if @activeEditor
      @activeEditor.onDidChangeCursorPosition (cursor) =>
        closeMsgs = []
        for msg in @messages
          if msg.getRange().containsPoint(cursor["newBufferPosition"])
            closeMsgs.push(msg)

        if closeMsgs.length == 0
          @clearSelection()
        else
          closeMsgs.sort (msg1, msg2) =>
                  range1 = msg1.getRange()
                  range2 = msg2.getRange()
                  delta1 = @pointDistance(cursor["newBufferPosition"], range1.start)
                  delta2 = @pointDistance(cursor["newBufferPosition"], range2.start)

                  if delta1[0] < delta2[0]
                    return -1
                  else if delta1[0] > delta2[0]
                    return 1
                  else 
                    if delta1[1] < delta2[1]
                      return -1
                    else if delta1[1] > delta2[1]
                      return 1
                    else
                      return 0
          @select(closeMsgs[0])

  clear: ->
    @messages.map (msg) -> msg.destroy()


  removeDestroyed: (messages) ->
    return (msg for msg in messages when msg.destroyed isnt true)


  clearSelection: () ->
    @messages.map (msg) -> msg.update({'selected':false})
    @focus = null


  select: (msg) ->
    # This should be moved to be called on a 'destroyed' event from a mesage
    @messages = @removeDestroyed(@messages)

    @messages.map (msg) -> msg.update({'selected':false})
    @focus = msg
    msg.update({'selected':true})


  selectAndMoveCursor: (msg) ->
    @activeEditor.setCursorBufferPosition(msg.getRange().start)
    @select(msg)


  updateStyle: () ->
    lineHeightEm = atom.config.get("editor.lineHeight")
    fontSizePx = atom.config.get("editor.fontSize")
    lineHeight = lineHeightEm * fontSizePx
    styleList = ("atom-overlay .inline-message.is-right.up-#{n}{ top:#{(n+1)*lineHeight*-1}px; }" for n in [0..250])
    stylesheet = styleList.join("\n")
    ss = atom.styles.addStyleSheet(stylesheet)


  sortMessages: () ->
    @messages.sort (msg1, msg2) -> 
                        range1 = msg1.getRange()
                        range2 = msg2.getRange()
                        startComp = range1.start.compare(range2.start)
                        if startComp == 0
                          return range1.end.compare(range2.end)
                        else
                          return startComp


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
    @sortMessages()
  

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
    @sortMessages()


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
          @selectAndMoveCursor(msg)
          return
    else
      stopAtNext = false
      for msg in @messages
        if stopAtNext is true
          @selectAndMoveCursor(msg)
          return
        if msg.selected is true
          stopAtNext = true
    # If nothing, select the first message
    @selectAndMoveCursor(@messages[0])


  prevMessage: () ->
    stopAtNext = false
    for msg in @messages.slice(0).reverse()
      if stopAtNext is true
        @selectAndMoveCursor(msg)
        return
      if msg.selected is true
        stopAtNext = true
    @selectAndMoveCursor(@messages[@messages.length - 1])


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









