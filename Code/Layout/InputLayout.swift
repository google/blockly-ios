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
Stores information for positioning `Input` areas on-screen.
*/
@objc(BKYInputLayout)
public class InputLayout: Layout {
  // MARK: - Properties

  /** The target `Input` to layout */
  public let input: Input

  /** The corresponding `BlockGroupLayout` object seeded by `self.input.connectedBlock`. */
  public var blockGroupLayout: BlockGroupLayout! {
    didSet {
      blockGroupLayout?.parentLayout = self
    }
  }

  /** The corresponding layouts for `self.input.fields[]` */
  public private(set) var fieldLayouts = [FieldLayout]()

  // MARK: - Initializers

  public required init(input: Input, parentLayout: BlockLayout?) {
    self.input = input
    super.init(parentLayout: parentLayout)
    self.input.delegate = self
    self.blockGroupLayout = BlockGroupLayout(parentLayout: self)
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return ([blockGroupLayout] as [Layout]) + (fieldLayouts as [Layout])
  }

  public override func layoutChildren() {
    // Update relative position/size of fields
    for fieldLayout in fieldLayouts {
      fieldLayout.layoutChildren()

      // TODO:(vicng) Figure out new positions for each field
    }

    // Update relative position/size of blocks
    blockGroupLayout.layoutChildren()

    // TODO:(vicng) Figure out new positions for the block group

    self.size = sizeThatFitsForChildLayouts()
  }

  // MARK: - Public

  /** Appends a fieldLayout to `self.fieldLayouts` and sets its `parentLayout` to this instance. */
  public func appendFieldLayout(fieldLayout: FieldLayout) {
    fieldLayout.parentLayout = self
    fieldLayouts.append(fieldLayout)
  }

  /** Removes `self.fieldLayouts[index]`, sets its `parentLayout` to nil, and returns it. */
  public func removeFieldLayoutAtIndex(index: Int) -> FieldLayout {
    let fieldLayout = fieldLayouts.removeAtIndex(index)
    fieldLayout.parentLayout = nil
    return fieldLayout
  }
}

// MARK: - InputDelegate

extension InputLayout: InputDelegate {
  public func inputDidChange(input: Input) {
    // TODO:(vicng) Potentially generate an event to update the source block of this input
  }
}
