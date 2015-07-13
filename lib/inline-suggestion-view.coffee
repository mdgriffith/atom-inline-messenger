class SuggestionView extends HTMLElement

  initialize: (msg) ->
    @classList.add('inline-suggestion')


    badge = document.createElement('span')
    badge.textContent = msg.severity
    badge.classList.add("badge")
    badge.classList.add("severity-#{msg.severity}")
    @appendChild(badge)

    # Create message element
    message = document.createElement('div')
    message.textContent = msg.message
    message.classList.add('message')
    @appendChild(message)

    suggestion = document.createElement('div')
    suggestion.classList.add('suggested')
    suggestion.textContent = msg.suggestedCode
    
    @appendChild(suggestion)

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