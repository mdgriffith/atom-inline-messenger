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
      description: "At the bottom of a suggestion, Show keyboard shortcut reminder for accepting it."
    acceptSuggestionAnimation:
      type: "boolean"
      default: true
      description: "Show a small highlight flash when suggested code is accepted."
    showSeverityBadge:
      type: "boolean"
      default: false
      description: "Show a text badge on every message that states its severity, such as 'Warning' or 'Error'"

  subscriptions: null
  messages:[]
  focus: null
  activeEditor: null
  fontSizePx: null
  lineHeightEm: null

  activate: (state) ->

    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:accept-suggestion': =>
        @acceptSuggestion()

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:next-message': =>
        @nextMessage()

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-inline-messenger:prev-message': =>
        @prevMessage()

    @activeEditor = atom.workspace.getActiveTextEditor()
    @subscriptions.add @cursorMovementSubscription()
    @updateStyle()

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem =>
      @activeEditor = atom.workspace.getActiveTextEditor()
      @subscriptions.add @cursorMovementSubscription()

    @subscriptions.add atom.config.observe 'editor.lineHeight', (newValue) =>
      if @lineHeightEm != newValue
        @updateStyle()

    @subscriptions.add atom.config.observe 'editor.fontSize', (newValue) =>
      if @fontSizePx != newValue
        @updateStyle()

    @subscriptions.add atom.config.observe 'inline-messenger.messagePositioning', (newValue) =>
      @messages.map (msg) -> msg.update({positioning:newValue.toLowerCase()})

    @subscriptions.add atom.config.observe 'inline-messenger.showSeverityBadge', (newValue) =>
      @messages.map (msg) -> msg.update({showBadge:newValue})


  deactivate: ->
    @subscriptions.dispose()
    @clear()


  serialize: ->
    messageViewState: @messageView.serialize()


  pointDistance: (point1, point2) ->
    deltaRow = Math.abs(point1.row-point2.row)
    deltaColumn = Math.abs(point1.column-point2.column)
    return [deltaRow, deltaColumn]


  cursorMovementSubscription: () ->
    if @activeEditor
      @activeEditor.onDidChangeCursorPosition (cursor) => @selectUnderCursor(cursor)


  selectUnderCursor: (cursor) ->
    if @messages.length == 0
      return

    if not @activeEditor
      return

    cursor = cursor or @activeEditor.getLastCursor()
    cursorRange = cursor.getMarker().getBufferRange()
    # closeMsgs = []
    closest = null
    closestRange = null
    for msg in @messages
      msgRange = msg.getRange()
      if msgRange.containsPoint(cursorRange.start) and msgRange.containsPoint(cursorRange.end)
        if closest is null
          closest = msg
          closestRange = msgRange
        else
          if closestRange.compare(msgRange) == 1 # this range starts after the argument or is contained by it.
            closest = msg
            closestRange = msgRange
      else if closest isnt null
        # Then we've passed the messages that are relevant
        break
    if closest isnt null
      @select(closest)
    else
      @clearSelection()


  clear: ->
    @messages.forEach (msg) -> msg.destroy()


  removeDestroyed: (messages) ->
    return (msg for msg in messages when not msg.destroyed)


  clearSelection: () ->
    @messages.forEach (msg) -> msg.update({'selected':false})
    @focus = null


  select: (msg) ->
    # This should be moved to be called on a 'destroyed' event from a mesage
    @messages = @removeDestroyed(@messages)

    @messages.map (msg) -> msg.update({'selected':false})
    @focus = msg
    msg.update({'selected':true})


  selectAndMoveCursor: (msg) ->
    @activeEditor.setCursorBufferPosition(msg.getRange().start, {autoscroll:false})
    @activeEditor.scrollToCursorPosition()
    @select(msg)


  updateStyle: () ->
    @lineHeightEm = atom.config.get("editor.lineHeight")
    @fontSizePx = atom.config.get("editor.fontSize")
    lineHeight = @lineHeightEm * @fontSizePx

    # This is a guess because I cant find a way to grab character width.
    # So, golden ratio?
    fontWidthHeightRatio = 0.618

    cssIsUpCls = 'atom-overlay inline-message.is-right.up-'
    styleList = (n for n in [0..250]).map (n) ->
      "#{cssIsUpCls}#{n}{ top:#{(n+1)*lineHeight*-1}px;}"

    cssIsRightCls = 'atom-overlay inline-message.is-right.right-'
    styleList = styleList.concat (n for n in [0..250]).map (n) =>
      "#{cssIsRightCls}#{n}{ left:#{(n*@fontSizePx)*fontWidthHeightRatio}px; }"
    stylesheet = styleList.join("\n")
    atom.styles.addStyleSheet(stylesheet)


  severityPriority: (severity) ->
    if severity == "info"
      return 0
    else if severity == "suggestion"
      return 1
    else if severity == "warning"
      return 2
    else if severity == "error"
      return 3
    else
      return 0

  sortMessages: () ->
    # Messages should be sorted by
    # start position (closer to top first)
    # then column position (closer to start, first)
    # then by size, as far as how many rows spanned (larger -> first)
    # then by how long the message is (longer -> first)
    @messages.sort (msg1, msg2) =>
      range1 = msg1.getRange()
      range2 = msg2.getRange()
      startComp = range1.start.compare(range2.start)
      if startComp == 0
        rowSize1 = Math.abs(range1.end.row - range1.start.row)
        rowSize2 = Math.abs(range2.end.row - range2.start.row)
        if (rowSize1 - rowSize2) == 0
          # console.log 
          svr1 = @severityPriority(msg1.severity)
          svr2 = @severityPriority(msg2.severity)
          return svr2 - svr1
          # return 0
        else
          return rowSize2 - rowSize1
      else
        return startComp


  nextMessage: () ->
    if @messages.length == 0
      return
    # Find the first message after the cursor,
    # and only after the selected ones
    cursorBuffPos = @activeEditor.getCursorBufferPosition()
    if @focus isnt null
      afterFocused = false
      for msg in @messages
        if afterFocused is true
          # if range.start.row >= cursorBuffPos.row
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
        if afterFocused is true
          # if range.start.row <= cursorBuffPos.row
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
    @selectAndMoveCursor(@messages[@messages.length-1])


  acceptSuggestion: () ->
    if @focus is null
      return
    if @focus.type == 'suggestion'
      newText = @focus.suggestion
      range = @focus.getRange()


      activeBuffer = @activeEditor.getBuffer()
      @focus.destroy()
      newRange = activeBuffer.setTextInRange(range, newText)
      if atom.config.get('inline-messenger.acceptSuggestionAnimation') is true
        @animateReplacementBlink(newRange)


  animateReplacementBlink: (range) ->
    marker = @activeEditor.markBufferRange(range)
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

  equivalentMsg: (msg1, msg2) ->
    props = ['text', 'html', 'severity', 'suggestion', 'debug']
    allPropsareEqual = props.every (prop) -> msg1[prop] == msg2[prop]
    if allPropsareEqual is true
      return msg1.getRange().isEqual(msg2.range)
    return false

  addMessage: ({range, text, html, severity, suggestion, trace,  debug}) ->
    if suggestion is null or suggestion is undefined
      msgType = 'message'
    else
      msgType = 'suggestion'

    if severity is null or severity is undefined
      if msgType == 'suggestion'
        severity = 'suggestion'
    if badge is null or badge is undefined
      badge = severity
    # for msg in @messages
    #   if @equivalentMsg msg, {
    #       text: text,
    #       html: html,
    #       severity: severity,
    #       suggestion: suggestion,
    #       trace: trace,
    #       debug: debug,
    #       range: range
    #     }
    #     return msg


    pos = atom.config.get('inline-messenger.messagePositioning').toLowerCase()
    kbd = atom.config.get 'inline-messenger.showKeyboardShortcutForSuggestion'
    showBadge = atom.config.get 'inline-messenger.showSeverityBadge'
    shortcut = atom.keymaps.findKeyBindings({command:'atom-inline-messenger:accept-suggestion'})[0]
    msg = new Message
      editor: @activeEditor
      type: msgType
      range: range
      suggestion: suggestion
      positioning: pos
      text: text
      severity: severity
      debug: debug
      showShortcuts: kbd
      shortcut: shortcut.keystrokes
      showBadge: showBadge
      badge: badge
      trace: trace
      html: html
    @messages.push msg
    return msg


  message: ({range, text, html, severity, suggestion, trace,  debug}) ->
    msg = @addMessage
      range:range
      text:text
      html:html
      severity:severity
      suggestion:suggestion
      trace:trace
      debug:debug
    @sortMessages()
    @selectUnderCursor()
    return msg


  manyMessages: (msgs) ->
    newMsgs = msgs.map (msg) =>
      @addMessage({
        range:msg.range
        text:msg.text
        html:msg.html
        severity:msg.severity
        suggestion:msg.suggestion
        trace:msg.trace
        debug:msg.debug
      })
      
    @sortMessages()
    @selectUnderCursor()
    return newMsgs


  provideInlineMessenger: () ->
    message: @message.bind(this)
    manyMessages: @manyMessages.bind(this)
