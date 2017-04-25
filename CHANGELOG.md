# [Version 0.7.4](https://github.com/google/blockly-ios/tree/0.7.4) (Apr 2017)

- Updates Cocoapods podspec file to specify AEXML 4.1.0 to accomodate Swift 3.1.

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
