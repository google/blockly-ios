/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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
 Class for a `FieldColor`-based `Layout`.
 */
@objc(BKYFieldColorLayout)
public class FieldColorLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldColor` that backs this layout
  public let fieldColor: FieldColor

  /// The checkbox value that should be used when rendering this layout
  public var color: UIColor {
    return fieldColor.color
  }

  // MARK: - Initializers

  public init(fieldColor: FieldColor, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldColor = fieldColor
    super.init(field: fieldColor, engine: engine, measurer: measurer)

    fieldColor.delegate = self
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  public override func didUpdateField(field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Updates `self.fieldColor` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - Parameter color: The value used to update `self.fieldColor`.
   */
  public func updateColor(color: UIColor) {
    // Setting to a new color automatically fires a listener to update the layout
    fieldColor.color = color
  }
}
