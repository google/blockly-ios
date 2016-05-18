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

/*
 Abstract class for storing information on how to render and position an `Input` on-screen.
 */
@objc(BKYInputLayout)
public class InputLayout: Layout {
  // MARK: - Properties

  /// The target `Input` to layout
  public final let input: Input

  /// Convenience property returning `self.parentLayout` as a `BlockLayout`
  public final var parentBlockLayout: BlockLayout? {
    return parentLayout as? BlockLayout
  }

  /// The corresponding `BlockGroupLayout` object seeded by `self.input.connectedBlock`.
  public private(set) final var blockGroupLayout: BlockGroupLayout!

  /// The corresponding `BlockGroupLayout` object seeded by `self.input.connected`.
  public private(set) final var shadowBlockGroupLayout: BlockGroupLayout!

  /// The block group layout that should be rendered
  public var renderedBlockGroupLayout: BlockGroupLayout {
    if blockGroupLayout.blockLayouts.count == 0 && shadowBlockGroupLayout.blockLayouts.count > 0 {
      return shadowBlockGroupLayout
    }

    return blockGroupLayout
  }

  /// The corresponding layouts for `self.input.fields[]`
  public private(set) final var fieldLayouts = [FieldLayout]()

  /// Flag for if this input is the first child in its parent's block layout
  public var isFirstChild: Bool {
    return parentBlockLayout?.inputLayouts.first == self ?? false
  }

  /// Flag for if this input is the last child in its parent's block layout
  public var isLastChild: Bool {
    return parentBlockLayout?.inputLayouts.last == self ?? false
  }

  /// Flag for if its parent block renders its inputs inline
  public var isInline: Bool {
    return parentBlockLayout?.block.inputsInline ?? false
  }

  // MARK: - Initializers

  public init(input: Input, engine: LayoutEngine, factory: LayoutFactory) throws {
    self.input = input
    super.init(engine: engine)

    // Create `self.blockGroupLayout` and `self.shadowBlockGroupLayout`.
    // This is done after super.init because you can't call a throwing method prior to
    // initialization.
    blockGroupLayout = try factory.layoutForBlockGroupLayout(engine: engine)
    blockGroupLayout.parentLayout = self
    shadowBlockGroupLayout = try factory.layoutForBlockGroupLayout(engine: engine)
    shadowBlockGroupLayout.parentLayout = self
  }

  // MARK: - Public

  /**
  Appends a fieldLayout to `self.fieldLayouts` and sets its `parentLayout` to this instance.

  - Parameter fieldLayout: The `FieldLayout` to append.
  */
  public func appendFieldLayout(fieldLayout: FieldLayout) {
    fieldLayout.parentLayout = self
    fieldLayouts.append(fieldLayout)
  }

  /**
  Removes `self.fieldLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter index: The index to remove from `self.fieldLayouts`.
  - Returns: The `FieldLayout` that was removed.
  */
  public func removeFieldLayoutAtIndex(index: Int) -> FieldLayout {
    let fieldLayout = fieldLayouts.removeAtIndex(index)
    fieldLayout.parentLayout = nil
    return fieldLayout
  }

  /**
  Removes all elements from `self.fieldLayouts`, sets their `parentLayout` to nil, and resets
  `self.blockGroupLayout`.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func reset(updateLayout updateLayout: Bool) {
    while fieldLayouts.count > 0 {
      removeFieldLayoutAtIndex(0)
    }

    self.blockGroupLayout.reset(updateLayout: false)

    if updateLayout {
      updateLayoutUpTree()
    }
  }
}

// MARK: - InputDelegate implementation

extension InputLayout: InputDelegate {
}
