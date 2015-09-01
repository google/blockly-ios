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

  /// The target `Input` to layout
  public let input: Input

  /// The corresponding `BlockGroupLayout` object seeded by `self.input.connectedBlock`.
  public var blockGroupLayout: BlockGroupLayout {
    didSet {
      blockGroupLayout.parentLayout = self
    }
  }

  /// The corresponding layouts for `self.input.fields[]`
  public private(set) var fieldLayouts = [FieldLayout]()

  /// The minimal amount of width required to render `fieldLayouts`, specified as a Workspace
  /// coordinate system unit.
  public var minimalFieldWidthRequired: CGFloat {
    // TODO:(vicng) Add inline padding to the "0" value
    return fieldLayouts.count > 0 ?
      (fieldLayouts.last!.relativePosition.x + fieldLayouts.last!.size.width) : 0
  }

  // MARK: - Initializers

  public required init(input: Input, workspaceLayout: WorkspaceLayout!,
    parentLayout: BlockLayout) {
      self.input = input
      self.blockGroupLayout = BlockGroupLayout(workspaceLayout: workspaceLayout, parentLayout: nil)
      super.init(workspaceLayout: workspaceLayout, parentLayout: parentLayout)
      self.input.delegate = self
      self.blockGroupLayout.parentLayout = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return ([blockGroupLayout] as [Layout]) + (fieldLayouts as [Layout])
  }

  public override func layoutChildren() {
    var xOffset: CGFloat = 0
    var maxYFieldPoint: CGFloat = 0

    // Update relative position/size of fields
    for fieldLayout in fieldLayouts {
      fieldLayout.layoutChildren()

      // TODO:(vicng) Add inline x padding
      fieldLayout.relativePosition.x = xOffset
      fieldLayout.relativePosition.y = 0

      xOffset += fieldLayout.size.width
      maxYFieldPoint = max(fieldLayout.relativePosition.y + fieldLayout.size.height,
        maxYFieldPoint)
    }

    // Update relative position/size of blocks
    blockGroupLayout.layoutChildren()

    let inputsInline = (parentLayout as? BlockLayout)?.block.inputsInline ?? false

    if (self.input.type == .Value && inputsInline) || self.input.type == .Statement {
      // TODO:(vicng) Add inline x padding
      blockGroupLayout.relativePosition.x = xOffset
      blockGroupLayout.relativePosition.y = 0
    } else if (self.input.type == .Value && !inputsInline) {
      // TODO:(vicng) Do a better job positioning this
      blockGroupLayout.relativePosition.x = xOffset
      blockGroupLayout.relativePosition.y = 0
    } else {
      blockGroupLayout.relativePosition = WorkspacePointZero
    }

    self.size = sizeThatFitsForChildLayouts()

    if self.input.type == .Dummy {
      // TODO:(vicng) Add extra padding at the end
    }
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

  // MARK: - Internal

  /**
  Allow the input layout to use more width when rendering its field layouts.

  If the given width is larger than the minimal amount needed, the layout is resized and its
  elements are repositioned.

  If the given width is not large enough, then all elements in the layout remain unchanged.

  - Parameter width: A width value, specified in the Workspace coordinate system.
  */
  internal func maximizeFieldWidthTo(width: CGFloat) {
    let minimalFieldWidthRequired = self.minimalFieldWidthRequired
    if width <= minimalFieldWidthRequired {
      return
    }

    let widthDifference = width - minimalFieldWidthRequired
    self.size.width += widthDifference

    // Shift fields based on new width and alignment
    if self.input.alignment == .Centre || self.input.alignment == .Right {
      let shiftAmount = (self.input.alignment == .Centre) ?
        floor(widthDifference / 2) : widthDifference
      for fieldLayout in fieldLayouts {
        fieldLayout.relativePosition.x += shiftAmount
      }
    }

    let inputsInline = (parentLayout as? BlockLayout)?.block.inputsInline ?? false

    if self.input.type != .Value || !inputsInline {
      // Shift the block group layout the entire width difference
      self.blockGroupLayout.relativePosition.x += widthDifference
    }
  }
}

// MARK: - InputDelegate

extension InputLayout: InputDelegate {
  public func inputDidChange(input: Input) {
    // TODO:(vicng) Potentially generate an event to update the source block of this input
  }
}
