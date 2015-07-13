

class MessengerView extends HTMLElement
  initialize: ->
    @classList.add('indentation-indicator', 'inline-block')

    # @activeItemSubscription = atom.workspace.onDidChangeActivePaneItem =>
    #   @update()

    @update()

  # Public: Destroys the indicator.
  # destroy: ->
    # @activeItemSubscription.dispose()

  # Public: Updates the indicator.
  update: ->
    editor = atom.workspace.getActiveTextEditor()

    if editor