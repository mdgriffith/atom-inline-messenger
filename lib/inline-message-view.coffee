class MessageView extends HTMLElement

  initialize: (msg) ->
    @classList.add('inline-message')
    if msg.type == 'suggestion'
       @classList.add('inline-suggestion')

    @classList.add("severity-#{msg.severity}")
    if msg.correctIndentation is true
      @classList.add("indentation-correction")

    if msg.positioning == "below"
      @classList.add("is-below")
    else if msg.positioning == "right"
      @classList.add("is-right")
      @classList.add("up-#{msg.offsetFromTop}")

    if msg.selected is true
      @classList.add("is-selected")

    message = document.createElement('div')
    if msg.debug is true
      message.classList.add('message')
      message.textContent = msg.debugText()
      @appendChild(message)

    else if msg.type == 'message'
      message.classList.add('message')
      message.textContent = msg.text
      @appendChild(message)
    else if msg.type == 'suggestion'
      # Create message element
      message.textContent = msg.text
      message.classList.add('message')
      @appendChild(message)

      suggestion = document.createElement('div')
      suggestion.classList.add('suggested')
      suggestion.textContent = msg.suggestion
      @appendChild(suggestion)

      rem = true
      if rem
        shortcut = document.createElement('div')
        shortcut.classList.add('keyboard-shortcut-reminder')
        shortcut.innerHTML = "<span class='kbd'>cmd-shift-enter</span> to accept suggestion"
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