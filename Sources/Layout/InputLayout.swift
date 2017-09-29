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

import UIKit

/**
 Abstract class for storing information on how to render and position an `Input` on-screen.
 */
@objc(BKYInputLayout)
@objcMembers open class InputLayout: Layout {
  // MARK: - Properties

  /// The target `Input` to layout
  public final let input: Input

  /// Convenience property returning `self.parentLayout` as a `BlockLayout`
  public final var parentBlockLayout: BlockLayout? {
    return parentLayout as? BlockLayout
  }

  /// The corresponding `BlockGroupLayout` object seeded by `self.input.connectedBlock`.
  public fileprivate(set) final var blockGroupLayout: BlockGroupLayout!

  /// The corresponding layouts for `self.input.fields[]`
  public fileprivate(set) final var fieldLayouts = [FieldLayout]()

  /// The line height of the first line in the input layout, specified as a Workspace coordinate
  /// system unit. It is used for vertical alignment purposes and should be updated during
  /// `performLayout(includeChildren:)`.
  open var firstLineHeight: CGFloat = 0

  /// Flag for if this input is the first child in its parent's block layout
  open var isFirstChild: Bool {
    return parentBlockLayout?.inputLayouts.first == self
  }

  /// Flag for if this input is the last child in its parent's block layout
  open var isLastChild: Bool {
    return parentBlockLayout?.inputLayouts.last == self
  }

  // MARK: - Initializers

  /**
   Initializes the input layout.

   - parameter input: The `Input` model for this layout.
   - parameter engine: The `LayoutEngine` that will build this layout.
   - parameter factory: The `LayoutFactory` to build the blockGroupLayout.
   */
  public init(input: Input, engine: LayoutEngine, factory: LayoutFactory) throws {
    self.input = input
    super.init(engine: engine)

    // Create `self.blockGroupLayout` and `self.shadowBlockGroupLayout`.
    // This is done after super.init because you can't call a throwing method prior to
    // initialization.
    blockGroupLayout = try factory.makeBlockGroupLayout(engine: engine)
    adoptChildLayout(blockGroupLayout)
  }

  // MARK: - Public

  /**
  Appends a fieldLayout to `self.fieldLayouts` and sets its `parentLayout` to this instance.

  - parameter fieldLayout: The `FieldLayout` to append.
  */
  open func appendFieldLayout(_ fieldLayout: FieldLayout) {
    fieldLayouts.append(fieldLayout)
    adoptChildLayout(fieldLayout)
  }

  /**
  Removes `self.fieldLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - parameter index: The index to remove from `self.fieldLayouts`.
  - returns: The `FieldLayout` that was removed.
  */
  @discardableResult
  open func removeFieldLayout(atIndex index: Int) -> FieldLayout {
    let fieldLayout = fieldLayouts.remove(at: index)
    removeChildLayout(fieldLayout)
    return fieldLayout
  }

  /**
  Removes all elements from `self.fieldLayouts`, sets their `parentLayout` to nil, and resets
  `self.blockGroupLayout`.

  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  open func reset(updateLayout: Bool) {
    while fieldLayouts.count > 0 {
      removeFieldLayout(atIndex: 0)
    }

    self.blockGroupLayout.reset(updateLayout: false)

    if updateLayout {
      updateLayoutUpTree()
    }
  }
}
