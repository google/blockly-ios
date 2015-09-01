/*
* Copyright 2015 Google Inc. All Rights Reserved.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation

// MARK: -

/*
Stores information on how to render and position a `Block` on-screen.
*/
@objc(BKYBlockLayout)
public class BlockLayout: Layout {
  // MARK: - Properties

  /// The `Block` to layout.
  public let block: Block

  /// The corresponding layout objects for `self.block.inputs[]`
  public private(set) var inputLayouts = [InputLayout]()

  /// A list of all `FieldLayout` objects belonging under this `BlockLayout`.
  public var fieldLayouts: [FieldLayout] {
    var fieldLayouts = [FieldLayout]()
    for inputLayout in inputLayouts {
      fieldLayouts += inputLayout.fieldLayouts
    }
    return fieldLayouts
  }

  /// Z-position of the block layout. Those with higher values should render on top of those with
  /// lower values.
  public var zPosition: CGFloat = 0 {
    didSet {
      if zPosition != oldValue {
        self.delegate?.layoutDidChange(self)
      }
    }
  }

  /// Whether this block is the first child of its parent, which must be a `BlockGroupLayout`.
  public var topBlockInBlockLayout: Bool {
    return parentBlockGroupLayout.blockLayouts[0] == self ?? false
  }

  /// The parent block group layout
  public var parentBlockGroupLayout: BlockGroupLayout {
    return parentLayout as! BlockGroupLayout
  }

  // MARK: - Initializers

  public required init(
    block: Block, workspaceLayout: WorkspaceLayout!, parentLayout: BlockGroupLayout) {
      self.block = block
      super.init(workspaceLayout: workspaceLayout, parentLayout: parentLayout)
      self.block.delegate = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return inputLayouts
  }

  public override func layoutChildren() {
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var maximumFieldWidth: CGFloat = 0
    var currentLineHeight: CGFloat = 0
    var previousInputLayout: InputLayout?

    // Update relative position/size of inputs
    for inputLayout in inputLayouts {

      // Offset this input layout based on the previous one
      if block.inputsInline &&
        (previousInputLayout?.input.type == .Value || previousInputLayout?.input.type == .Dummy) &&
        (inputLayout.input.type == .Value || inputLayout.input.type == .Dummy) {
          // Continue appending to this line
          // TODO:(vicng) Add inline x padding
          xOffset += previousInputLayout!.size.width
      } else {
        // Start a new line
        // TODO:(vicng) Add inline x/y padding
        xOffset = 0
        yOffset += currentLineHeight
        currentLineHeight = 0
      }

      inputLayout.layoutChildren()
      inputLayout.relativePosition.x = xOffset
      inputLayout.relativePosition.y = yOffset

      // Update the maximum field width used
      if !block.inputsInline || inputLayout.input.type == .Statement {
        maximumFieldWidth =
          max(maximumFieldWidth, inputLayout.minimalFieldWidthRequired)
      }

      currentLineHeight = max(currentLineHeight, inputLayout.size.height)
      previousInputLayout = inputLayout
    }

    // Re-layout inputs based on new maximum width
    for inputLayout in inputLayouts {
      if !block.inputsInline || inputLayout.input.type == .Statement {
        inputLayout.maximizeFieldWidthTo(maximumFieldWidth)
      }
    }

    // Update the size required for this block
    self.size = sizeThatFitsForChildLayouts()
  }

  // MARK: - Public

  /**
  Appends an inputLayout to `self.inputLayouts` and sets its `parentLayout` to this instance.

  - Parameter inputLayout: The `InputLayout` to append.
  */
  public func appendInputLayout(inputLayout: InputLayout) {
    inputLayout.parentLayout = self
    inputLayouts.append(inputLayout)
  }

  /**
  Removes `self.inputLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter index: The index to remove from `inputLayouts`.
  - Returns: The `BlockLayout` that was removed.
  */
  public func removeInputLayoutAtIndex(index: Int) -> InputLayout {
    let inputLayout = inputLayouts.removeAtIndex(index)
    inputLayout.parentLayout = nil
    return inputLayout
  }
}

// MARK: - BlockDelegate

extension BlockLayout: BlockDelegate {
  public func blockDidChange(block: Block) {
    // TODO:(vicng) Potentially generate an event to update the corresponding view
  }
}
