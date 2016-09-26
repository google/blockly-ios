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

/**
Protocol for measuring the size of a `Layout` when it is rendered.
*/
@objc(BKYFieldLayoutMeasurer)
public protocol FieldLayoutMeasurer {
  /**
  Measures and returns the amount of space needed to render a `FieldLayout`, in a `UIView`.

  - Parameter layout: The layout to measure
  - Parameter scale: The current scale of the layout's `workspaceLayout`.
  - Returns: The amount of space needed, in UIView coordinates.
  */
  static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize
}

/**
Abstract class for a `Field`-based `Layout`.
*/
@objc(BKYFieldLayout)
open class FieldLayout: Layout {
  // MARK: - Properties

  /// Object responsible for measuring the layout of this object.
  open var measurer: FieldLayoutMeasurer.Type

  /// The target field to layout
  public final let field: Field

  /// Flag determining if user interaction should be enabled for the corresponding view
  open var userInteractionEnabled: Bool {
    return field.editable
  }

  // MARK: - Initializers

  /**
   Initializes the field layout.

   - Parameter field: The `Field` model object to create a layout for.
   - Parameter engine: The `LayoutEngine` to associate with this layout.
   - Parameter measurer: The `FieldLayoutMeasurer.Type` to measure this field.
   */
  public init(field: Field, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.field = field
    self.measurer = measurer
    super.init(engine: engine)

    self.field.delegate = self
  }

  // MARK: - Super

  open override func performLayout(includeChildren: Bool) {
    // Measure the layout in the UIView coordinate system
    let layoutSize: CGSize = measurer.measureLayout(self, scale: self.engine.scale)

    // Convert the layout size back into the Workspace coordinate system
    self.contentSize = self.engine.workspaceSizeFromViewSize(layoutSize)

    // Force this field to be redisplayed
    sendChangeEvent(withFlags: Layout.Flag_NeedsDisplay)
  }
}

// MARK: - FieldDelegate implementation

extension FieldLayout: FieldDelegate {
  public func didUpdateField(_ field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }
}
