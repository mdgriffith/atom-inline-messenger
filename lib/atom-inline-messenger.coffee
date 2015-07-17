# { View } = require 'atom'
{CompositeDisposable} = require 'atom'
Message = require './message-model'


module.exports = Messenger =

  config:
    messagePositioning:
      type: "string"
      default: "Below"
      description: "Position multiline messages below or to the right of the highlighted text"
      enum: ["Below", "Right"]
    showKeyboardShortcutForSuggestion:
      type: "boolean"
      default: true
      description: "Show keyboard shortcut reminder at the bottom of a suggestion."
    acceptSuggestionAnimation:
      type: "boolean"
      default: true
      description: "Show a small highlight flash when suggested code is accepted."

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
      @activeEditor.onDidChangeCursorPosition (cursor) => @selectUnderCursor()
        

  selectUnderCursor: (cursor) ->
    cursor = @activeEditor.getLastCursor()
    cursorRange = cursor.getMarker().getBufferRange()
    if cursorRange.start != cursorRange.end
      @clearSelection()
      return
    cursorPos = cursor.getBufferPosition()\
    closeMsgs = []
    for msg in @messages
      if msg.getRange().containsPoint(cursorPos)
        closeMsgs.push(msg)

    if closeMsgs.length == 0
      @clearSelection()
    else
      closeMsgs.sort (msg1, msg2) =>
              range1 = msg1.getRange()
              range2 = msg2.getRange()
              delta1 = @pointDistance(cursorPos, range1.start)
              delta2 = @pointDistance(cursorPos, range2.start)
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
    styleList = ("atom-overlay inline-message.is-right.up-#{n}{ top:#{(n+1)*lineHeight*-1}px; }" for n in [0..250])
    stylesheet = styleList.join("\n")
    ss = atom.styles.addStyleSheet(stylesheet)


  sortMessages: () ->
    # Messages should be sorted by 
    # start position (closer to top first)
    # then column position (closer to start, first)
    # then by size, as far as how many rows spanned (larger -> first)
    # then by how long the message is (longer -> first)
    @messages.sort (msg1, msg2) -> 
                        range1 = msg1.getRange()
                        range2 = msg2.getRange()
                        startComp = range1.start.compare(range2.start)
                        if startComp == 0
                          rowSize1 = Math.abs(range1.end.row - range1.start.row)
                          rowSize2 = Math.abs(range2.end.row - range2.start.row)
                          if (rowSize1 - rowSize2) == 0
                            return msg2.text.length - msg1.text.length
                          else
                            return rowSize2 - rowSize1
                        else
                          return startComp


  message: ({range, text, severity, suggestion, debug}) ->
    if suggestion is null or suggestion is undefined
      msgType = 'message'
    else
      msgType = 'suggestion'

    if severity is null or severity is undefined
      if msgType == 'suggestion'
        severity = 'suggestion'
      else
        severity = 'info'

    msg = new Message
            editor: @activeEditor 
            type: msgType
            range: range
            suggestion: suggestion
            positioning: atom.config.get('atom-inline-messaging.messagePositioning').toLowerCase()
            text: text
            severity: severity
            debug: debug
            showShortcuts: atom.config.get('atom-inline-messaging.showKeyboardShortcutForSuggestion')
    @messages.push msg
    @sortMessages()
    @selectUnderCursor()

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
    # Find the first message after the cursor,
    # and only after the selected oned
    cursorBuffPos = @activeEditor.getCursorBufferPosition()
    if @focus isnt null
      afterFocused = false
      for msg in @messages
        range = msg.getRange()
        if afterFocused is true
          if range.start.row >= cursorBuffPos.row
            @selectAndMoveCursor(msg)
            return
        if msg.selected is true
          afterFocused = true
    else
      for msg in @messages
        range = msg.getRange()
        if range.start.row >= cursorBuffPos.row
          @selectAndMoveCursor(msg)
          return
    @selectAndMoveCursor(@messages[0])


  prevMessage: () ->
    if @messages.length == 0
      return
    cursorBuffPos = @activeEditor.getCursorBufferPosition()
    if @focus isnt null
      afterFocused = false
      for msg in @messages.slice(0).reverse()
        range = msg.getRange()
        if afterFocused is true
          if range.start.row <= cursorBuffPos.row
            @selectAndMoveCursor(msg)
            return
        if msg.selected is true
          afterFocused = true
    else
      for msg in @messages.slice(0).reverse()
        range = msg.getRange()
        if range.start.row <= cursorBuffPos.row
          @selectAndMoveCursor(msg)
          return
    @selectAndMoveCursor(@messages[0])



  acceptSuggestion: () ->
    if @focus is null
      return

    if @focus.type == 'suggestion'
      newText = @focus.suggestion
      range = @focus.range

      activeBuffer = @activeEditor.getBuffer()
      newRange = activeBuffer.setTextInRange(range, newText)

      @focus.destroy()
      if atom.config.get('atom-inline-messaging.messagePositioning') is true
        @animateReplacementBlink(newRange)


  provideInlineMessenger: () ->
    message: @message.bind(this)









