class SuggestionView extends HTMLElement

  initialize: (msg) ->
    @classList.add('inline-message')
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



    if msg.debug is true
      message = document.createElement('div')
      message.classList.add('message')
      message.textContent = msg.debugText()
      @appendChild(message)
    else
      # Create message element
      message = document.createElement('div')
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

fromSuggestion = (msg) ->
  MessageLine = new SuggestionElement()
  MessageLine.initialize(msg)
  MessageLine




module.exports = SuggestionElement = document.registerElement('inline-suggestion', prototype: SuggestionView.prototype)
module.exports.fromSuggestion = fromSuggestion