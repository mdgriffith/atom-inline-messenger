class MessageView extends HTMLElement

  initialize: (msg) ->
    # @classList.add('inline-message')
    @classList.add('inline-message')
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
      message.textContent = msg.debugText()
    else
      message.textContent = msg.text
    message.classList.add('message')

    @appendChild(message)
    
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