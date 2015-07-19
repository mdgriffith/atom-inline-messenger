class MessageView extends HTMLElement

  initialize: (msg) ->
    # @classList.add('inline-message')
    if msg.type == 'suggestion'
      @classList.add('inline-suggestion')

    @classList.add("severity-#{msg.severity}")
    if msg.correctIndentation is true
      @classList.add('indentation-correction')

    if msg.correctLastLine is true
      @classList.add('empty-lastline-correction')

    if msg.positioning == "below"
      @classList.add("is-below")
    else if msg.positioning == "right"
      @classList.add("is-right")
      @classList.add("right-#{msg.longestLineLength}")
      @classList.add("up-0")
      # @classList.add("up-#{msg.offsetFromTop}")

    if msg.selected is true
      @classList.add("is-selected")

    if msg.severity isnt null and msg.severity isnt undefined
      badge = document.createElement('div')
      badge.classList.add('badge')
      badge.textContent = msg.badge
      @appendChild(badge)
    if msg.showBadge is true and msg.severity isnt null and msg.severity isnt undefined
      @classList.add 'show-badge'

    message = document.createElement('div')
    message.classList.add('message')


    if msg.debug is true
      message.textContent = msg.debugText()
      @appendChild(message)

    else if msg.type == 'message'
      message.textContent = msg.text
      @appendChild(message)
    else if msg.type == 'suggestion'
      message.textContent = msg.text
      @appendChild(message)

      suggestion = document.createElement('div')
      suggestion.classList.add('suggested')
      suggestion.textContent = msg.suggestion
      @appendChild(suggestion)

      if msg.showShortcuts is true
        shortcut = document.createElement('div')
        shortcut.classList.add('keyboard-shortcut-reminder')
        kbd = "<span class='kbd'>#{msg.shortcut}</span>"
        shortcut.innerHTML = "#{kbd} to accept suggestion"
        @appendChild(shortcut)

    this


  # Returns an object that can be retrieved when package is activated
  serialize: ->


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
