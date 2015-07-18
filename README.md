# Inline Messenger for the Atom Editor

This package provides an inline messaging service for other packages.

With it, a package can show messages next to the relevant, highlighted code,  and optionally make a code suggestion for the selected text.

An example of an inline message.  Single line messages are underlined.  Multiline messages have a dotted line annotation to the left.

![Inline Messages](https://raw.githubusercontent.com/mdgriffith/atom-inline-messenger-example/master/img/inline-message.gif?token=AC54XW-QnrhkimH6dJcK5e67awSHD7wiks5VsvjswA%3D%3D)

An example of a message with a code suggestion.  The code suggestion is then accepted

![Suggestion](https://raw.githubusercontent.com/mdgriffith/atom-inline-messenger-example/master/img/inline-suggestion.gif?token=AC54XbSnGvf4CzBU9ItmUo31uRNDewc2ks5Vsvh_wA%3D%3D)

## Getting Started

The [Inline Messenger Example](https://github.com/mdgriffith/atom-inline-messenger-example) has example code on how to work with this package.


## Design Considerations

The goal was to create a service for inline messaging as you see this functionality reimplemented in many packages.

Design-wise, the priority was to be as unobtrusive to the code as possible.  For one line messages, the standard dotted underline was used to highlight a piece of code.

Though for multiline highlights this seemed to be obtrusive.  The solution was to have a dashed line along the gutter.  When the section of code is highlighted, it's obvious that the gutter annotation is connected to the highlighted text and the message.  It also doesn't interfere with the [git-diff](https://github.com/atom/git-diff) package.

![Inline Messages](https://raw.githubusercontent.com/mdgriffith/atom-inline-messenger-example/master/img/inline-message.gif?token=AC54XW-QnrhkimH6dJcK5e67awSHD7wiks5VsvjswA%3D%3D)

### Message Positioning

In case the user doesn't want messages to overlap with any code, you can set the message positioning setting to `Right` instead of `Below`.  

![Messages to the Right](https://raw.githubusercontent.com/mdgriffith/atom-inline-messenger-example/master/img/inline-message-right.gif)
