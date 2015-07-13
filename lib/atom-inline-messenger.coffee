# { View } = require 'atom'
{CompositeDisposable} = require 'atom'
Message = require './inline-message-view'
Suggestion = require './inline-suggestion-view'

module.exports = Messenger =
  testPackageView: null
  modalPanel: null
  subscriptions: null
  messages:[]
  listMode:true

  activate: (state) ->
    # @testPackageView = new TestPackageView(state.testPackageViewState)
    # @modalPanel = atom.workspace.addModalPanel(item: @testPackageView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'test-package:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @messageView.destroy()

  serialize: ->
    messageViewState: @messageView.serialize()


  render: ->
    if @listMode
      @renderListMode()
    else
      @renderBubbleMode()
  
  renderListMode: ->
    activeEditor = atom.workspace.getActiveTextEditor()
    for msg in @messages
      console.log msg
      anchorRange = [msg.range[0].slice(), msg.range[1].slice()]
      anchorRange[0][1] = 0
      anchorRange[0][0] = anchorRange[0][0]-1
      anchorRange[1] = anchorRange[0].slice()

      anchor = activeEditor.markBufferRange(anchorRange, {invalidate: 'never'})
      mark = activeEditor.markBufferRange(msg.range, {invalidate: 'never'})

      bubble = activeEditor.decorateMarker(
        anchor
        {
          type: 'overlay',
          position: 'tail',
          class: 'inline-message in-list'
          item: @renderElement(msg)
        }
      )
      activeEditor.decorateMarker(
        mark
        {
          type: 'highlight',
          class: 'inline-message-selection-highlight'
        }
      )

  renderBubbleMode: ->
    activeEditor = atom.workspace.getActiveTextEditor()
    for msg in @messages
      console.log msg
      # continue unless message.range?.containsPoint point
      mark = activeEditor.markBufferRange(msg.range, {invalidate: 'never'})

      bubble = activeEditor.decorateMarker(
        mark
        {
          type: 'overlay',
          position: 'head',
          class: 'inline-message'
          item: @renderElement(msg)
        }
      )
      activeEditor.decorateMarker(
        mark
        {
          type: 'highlight',
          class: 'inline-message-selection-highlight'
        }
      )


      # break
  renderElement: (element) ->
    if element.type == 'message'
      return @renderMessage(element)
    else if element.type == 'suggestion'
      return @renderSuggestion(element)


  renderMessage: (msg) ->
    bubble = document.createElement 'div'
    bubble.id = 'inline-message'
    bubble.classList.add("style-" + msg.style)
    if @listMode
      bubble.classList.add('in-list')
    bubble.appendChild Message.fromMsg(msg)
    bubble


  renderSuggestion: (msg) ->
    console.log "render suggestion"
    bubble = document.createElement 'div'
    bubble.id = 'inline-suggestion'
    if @listMode
      bubble.classList.add('in-list')
    bubble.appendChild Suggestion.fromSuggestion(msg)
    bubble

  message: ({start, end, content, style}) ->
    @messages.push
      type: 'message'
      range: [start, end]
      content: content
      style: style
    @render()

  suggest: ({start, end, message, suggestedCode, style}) ->
    console.log "add suggestion"
    @messages.push
      type: 'suggestion'
      range: [start, end]
      message: message
      suggestedCode: suggestedCode
      style: style
    @render()

    # TextBuffer.setTextInRange(range, text)

  provideInlineMessenger: () ->
    message: @message.bind(this)
    suggest: @suggest.bind(this)
    clear: -> console.log "clear"




