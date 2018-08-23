# [Version 1.2.2](https://github.com/google/blockly-ios/tree/1.2.2) (Feb 2018)

- Changes Blockly framework to a shared scheme in order to fix compilation
issue with Carthage
- Updates i18n messages from Web Blockly (as of 2018/02/12)

# [Version 1.2.1](https://github.com/google/blockly-ios/tree/1.2.1) (Dec 2017)

Updates:
- Opens the event framework so developers can add their own custom events.
- Opens `WorkbenchViewController` so developers can add their own UI states.
- Adds `keepTrashedBlocks` to the workbench, which controls if users can open
the trash folder. By default, it is set to `false` (matching default Web
behavior).
- Removes use of deprecated `characters` property on Strings.
- Changes the workbench to allow changing the viewport location based on
workspace location, and sets it to first open at the top-leading corner of the
workspace.
- Fixes `FieldCheckbox` to serialize XML into capitalized values, matching Web
behavior.
- Fixes turtle demo so it stops highlighting/scrolling blocks into view
if the user has edited the workspace.
- Updates i18n messages and compiled version of Web Blockly to latest
November 2017 release.

# [Version 1.2](https://github.com/google/blockly-ios/tree/1.2) (Oct 2017)

Additions:
- The UI now respects the iOS 11 "safe area" so that all visible content and
touch areas are displayed within the safe area. Currently, this only affects
apps running on iPhone X, since its defined safe area doesn't fully conform
to its screen dimensions.
- Adds method to `WorkspaceView`, to set the viewport to a reveal a specific
location.

Updates:
- Changes `LayoutFactory` to be a class instead of a protocol.
- Removes `DefaultLayoutFactory` and refactors its functionality into
`LayoutFactory`.
- Fixes "if-return" block to automatically disable itself if it isn't connected
to a procedure definition block.
- Fixes Turtle demo so it is zoomable and so it no longer allows the turtle to
run off-screen.
- Fixes bug in RTL where zooming caused the viewport to jump to a different
location.
- Fixes bug in RTL where dragging the first block onto an empty canvas caused
the block to temporarily flash at a different location.
- Fixes WorkspaceView from adding extra canvas padding to an empty workspace.

# [Version 1.1.3](https://github.com/google/blockly-ios/tree/1.1.3) (Oct 2017)

Updates:
- Updates the library to use Swift 4 syntax. This requires that developers
update to use Xcode 9.
- Adds `flipRtl` property to FieldImage, allowing images to be flipped in RTL
rendering
- Updates i18n messages and compiled version of Web Blockly to latest October
release.

Fixes:
- Fixes bug where cancelled touches weren't being handled inside
WorkbenchViewController, which caused state problems
- Fixes bug where popovers could be overdismissed

# [Version 1.1.2](https://github.com/google/blockly-ios/tree/1.1.2) (Sep 2017)

Updates:
- Allows disabled blocks to be dragged on the workspace
- Adds serialization for Block properties editable, deletable, movable, disabled,
and inputsInline

Fixes:
- Fixes code generator for iOS 11 so it sends the initial codegen request on the
main thread
- Fixes names of two codelab sounds
- Fixes bug where popover delegates were being overriden, which caused undo/redo
buttons to stay disabled after popover dismissal
- Fixes bug where non-top-level variables didn't always show up in the variable
drop-down picker
- Fixes FieldLayout from implicitly updating the layout tree on model changes,
and made it update explicitly.
- Fixes ViewBuilder bug where it would recycle views prior to calling a delegate
method that inspected view hierarchy
- Fixes WorkspaceViewController bug where the didRemoveBlockView() delegate method
wasn't being fired
- Fixes bug where the same variable block can be created multiple times
- Fixes Obj-C compilation error where WebKit protocol can't be found

# [Version 1.1.1](https://github.com/google/blockly-ios/tree/1.1.1) (July 2017)

- Fixes bug where dismissing a popover could dismiss `WorkbenchViewController`.
- Fixes trash can folder so it always appear above the undo/redo controls.

# [Version 1.1](https://github.com/google/blockly-ios/tree/1.1) (July 2017)

This version packs our biggest UI update thus far! Many changes were made to make
Blockly iOS look and feel more modern. These changes include:
- Custom popovers for entering a number and for picking an angle
- A fresh coat of paint to the UI that uses Material Design colors
- Automatic vertical alignment of fields and inputs
- Rounded block corners
- More consistent sizing and spacing for all blocks
- Changing block dragging so that it appears above all other layers
- Better visibility when highlighting connections between blocks
- Improved style configuration. More style options have been added to
`LayoutConfig` and `DefaultLayoutConfig`.
- Other minor UI fixes to improve usability

# [Version 1.0](https://github.com/google/blockly-ios/tree/1.0.0) (May 2017)

We're happy to announce that we've reached version 1.0 of Blockly iOS!

With this milestone, the project is at a point where all core components of Blockly
have been implemented on iOS. The API is relatively stable, and major performance
and memory issues from previous versions have been addressed.

Developers new to Blockly iOS should check out our
[codelab](https://developers.google.com/blockly/codelab/ios).
It walks you through the process of creating an iOS app with Blockly.

# [Version 0.7.4](https://github.com/google/blockly-ios/tree/0.7.4) (Apr 2017)

- Updates Cocoapods podspec file to specify AEXML 4.1.0 to accommodate Swift 3.1.

# [Version 0.7.3](https://github.com/google/blockly-ios/tree/0.7.3) (Apr 2017)

- For both `CodeGeneratorService#generateCode(forWorkspace:onCompletion:onError:)` and
`CodeGeneratorService#generateCode(forWorkspaceXML:onCompletion:onError:)`,
the callbacks for `onCompletion` and `onError` now include a `requestUUID` parameter.
- Updates Cocoapods podspec file to specify Swift 3.1.

# [Version 0.7.2](https://github.com/google/blockly-ios/tree/0.7.2) (Apr 2017)

- Adds workaround for whole-module-optimization compiler bug in Xcode 8.3/Swift 3.1.

# [Version 0.7.1](https://github.com/google/blockly-ios/tree/0.7.1) (Apr 2017)

- Fixes compile errors/warnings related to Swift 3.1 (when using Xcode 8.3+).

# [Version 0.7](https://github.com/google/blockly-ios/tree/0.7) (Apr 2017)

- Adds support for events and undo-redo functionality.
- The library is now localized to support all languages available in Blockly
Web (except for those unsupported by iOS itself).
- Allows native "extensions" to be run on Block objects, upon instantiation.
- Mutators and extensions can now be defined inside JSON Block definitions.
- New `LayoutConfig` options for coloring field labels (`FieldLabelTextColor` and
`FieldEditableTextColor`).
- Adds `workspace:willAddBlock:` and `workspace:didRemoveBlock:` to `WorkspaceListener`.

- IMPORTANT NOTE: `WorkbenchViewController` has been changed to expose a `BlockFactory`
instance, via the `blockFactory` property. Clients should use this instance when
creating new blocks inside the workbench, instead of using a separate instance.
`WorkbenchViewController` needs to use this block factory when re-creating blocks
or else it will not operate correctly (eg. for performing undo-redo actions).

# [Version 0.6](https://github.com/google/blockly-ios/tree/0.6) (Feb 2017)

- Adds variables and procedures
- Adds support for mutators (along with a default mutator for an if-else block)
- Changes Block and Field objects so that multiple listeners can listen for their changes
instead of just a single delegate.

# [Version 0.5.1](https://github.com/google/blockly-ios/tree/0.5.1) (Nov 2016)

- Fixes bugs with the turtle demo.
- Fixes FieldInputView being uneditable in the iPhone 7/7+ simulator.
- Fixes jumping bug while zooming the WorkspaceView.
- Adds a DefaultLayoutConfig option for rendering a "start hat".
- Changes the CodeGeneratorServiceRequest flow. This is a breaking change, see
  https://developers.google.com/blockly/guides/configure/ios/code-generators for more information.


# [Version 0.5.0](https://github.com/google/blockly-ios/tree/0.5.0) (Oct 2016)

- Developer preview release of Blockly for iOS.
