# Inline Messenger for the Atom Editor

Show messages next to the relevant code.  Also allows for a package to make code suggestions.

An example of a message
![](https://f.cloud.github.com/assets/671378/2241819/f8418cb8-9ce5-11e3-87e5-109e965986d0.png)

An example of a message with a code suggestion
![](https://f.cloud.github.com/assets/671378/2241819/f8418cb8-9ce5-11e3-87e5-109e965986d0.png)

## Getting Started

The [Inline Messenger Example](https://github.com/mdgriffith/atom-inline-messenger-example) has example code on how to work with this package.

This package provides a service you can use in other Atom projects.  To use
it, include `inline-messenger` in the `consumedServices` section of your `package.json`:

```json
{
  "name": "my-package",
  "consumedServices": {
    "inline-messenger": {
      "versions": {
        "^1.0.0": "consumeInlineMessenger"
      }
    }
  }
}
```

Then, in your package's main module, call methods on the service.

There is only one function, which is `message`.  This creates a message in the active editor. 

```coffee
module.exports =
  activate: -> 
    @messages = []

  consumeInlineMessenger: (messenger) ->
    @messenger = messenger

    @messages.push @messenger.message
              start: [22,0]  
              end: [25,8] 
              text: "A New Message"
              severity: "warning"

    @messages.push @messenger.message
              start: [35,0]  
              end: [35,8] 
              text: "A New Code Suggestion"
              suggestion: "myNewCodeSuggestion();"
              severity: "warning"

  deactivate: ->
    @messages.map (msg) -> msg.destroy()
```


## Commands

* `next-message` -> Jumps to the next message.  The default keyboard shortcut is alt-down
* `prev-message` -> Jumps to the previous message.  The default keyboard shortcut is alt-up
* `accept-suggestion` -> If the currently viewed message is a code suggestion, this command will make the suggested changes for you.  The default is cmd-shift-a


## Settings

* `Message Positioning` - For messages that span multiple lines, show them either below the highlighted code or to the right.  Defaults to below.
* `Show Keyboard Shortcut For Suggestions` - Show keyboard shortcut reminder at the bottom of a suggestion.  Defaults to true.
* `acceptSuggestionAnimation` - Show a small highlight flash when suggested code is accepted.  Defaults to true.









