class MessageView extends HTMLElement

  initialize: (msg) ->
    if msg.type == 'suggestion'
      @classList.add('inline-suggestion')

    @classList.add("severity-#{msg.severity}")
    if msg.correctIndentation
      @classList.add('indentation-correction')

    if msg.correctLastLine
      @classList.add('empty-lastline-correction')

    if msg.positioning == "below"
      @classList.add("is-below")
    else if msg.positioning == "right"
      @classList.add("is-right")
      @classList.add("right-#{msg.longestLineLength}")
      @classList.add("up-0")
      # @classList.add("up-#{msg.offsetFromTop}")

    if msg.selected
      @classList.add("is-selected")

    if msg.severity
      badge = document.createElement('div')
      badge.classList.add('badge')
      badge.textContent = msg.badge
      @appendChild(badge)
      if msg.showBadge
        @classList.add 'show-badge'

    message = document.createElement('div')
    message.classList.add('message')

    if msg.debug
      message.textContent = msg.debugText()
      @appendChild(message)
      return this
    else
      @renderContent message, msg
      @appendChild(message)

   
    if msg.type == 'suggestion'
      title = document.createElement('div')
      title.classList.add('suggestion-title')
      title.textContent = 'Code Suggestion '
      if msg.showShortcuts is true
        shortcut = document.createElement('span')
        shortcut.classList.add('keyboard-shortcut-reminder')
        kbd = "<span class='kbd'>#{msg.shortcut}</span>"
        shortcut.innerHTML = "#{kbd} to accept"
        title.appendChild(shortcut)
      @appendChild(title)

      suggestion = document.createElement('div')
      suggestion.classList.add('suggested')

      suggestion.textContent = msg.suggestion
      @appendChild(suggestion)

    if msg.trace and msg.trace.length > 0
      traceEl = document.createElement('div')
      traceEl.classList.add('trace')
      for tr in msg.trace
        traceStep = document.createElement('div')
        traceStep.classList.add('step')
        @renderContent traceStep, tr
        if tr.filePath
          traceStep.appendChild @renderLink(tr, addPath=true)
        traceEl.appendChild(traceStep)
      @appendChild(traceEl)
    this

  renderContent: (el, msg) ->
    if msg.html
      if typeof msg.html is 'string'
        el.innerHTML = msg.html
      else
        el.appendChild msg.html
    else
      el.textContent = msg.text


  renderLink: (message, {addPath}) ->
    displayFile = message.filePath
    atom.project.getPaths().forEach (path) ->
      return if message.filePath.indexOf(path) isnt 0 or displayFile isnt message.filePath # Avoid double replacing
      displayFile = message.filePath.substr( path.length + 1 ) # Remove the trailing slash as well
    el = document.createElement 'a'
    el.classList.add('trace-link')
    el.addEventListener 'click', =>
      @goToLocation message.filePath, message.range
    el.textContent = " #{displayFile}"
    if message.range
      el.textContent += " #{message.range.start.row + 1}:#{message.range.start.column + 1} "
    
    el

  goToLocation: (file, range) ->
    atom.workspace.open(file).then ->
      return unless range
      atom.workspace.getActiveTextEditor().setCursorBufferPosition(range.start)

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element

fromMsg = (msg) ->
  MessageLine = new MessageElement()
  MessageLine.initialize(msg)
  MessageLine


module.exports = MessageElement = document.registerElement('inline-message', prototype: MessageView.prototype)
module.exports.fromMsg = fromMsg
