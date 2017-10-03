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
 Class for a `FieldDate`-based `Layout`.
 */
@objc(BKYFieldDateLayout)
@objcMembers open class FieldDateLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldDate` that backs this layout
  private let fieldDate: FieldDate

  /// The value that should be used when rendering this layout
  open var textValue: String {
    return dateFormatter.string(from: fieldDate.date as Date)
  }

  /// The date value that should be used when rendering this layout
  open var date: Date {
    return fieldDate.date
  }

  // Formatter used to generate `self.textValue`
  open let dateFormatter: DateFormatter

  // MARK: - Initializers

  /**
   Initializes the date field layout.

   - parameter fieldDate: The `FieldDate` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(fieldDate: FieldDate, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type,
              dateFormatter: DateFormatter? = nil)
  {
    self.fieldDate = fieldDate

    if let formatter = dateFormatter {
      self.dateFormatter = formatter
    } else {
      // By default, format dates based on the user's current locale, in a short style
      // (which is generally numeric)
      self.dateFormatter = DateFormatter()
      self.dateFormatter.locale = Locale.current
      self.dateFormatter.dateStyle = .short
    }
    super.init(field: fieldDate, engine: engine, measurer: measurer)
  }

  // MARK: - Public

  /**
   Updates `self.fieldDate` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - parameter date: The value used to update `self.fieldDate`.
   */
  open func updateDate(_ date: Date) {
    guard fieldDate.date != date else { return }

    captureChangeEvent {
      fieldDate.date = date
    }

    // Perform a layout up the tree
    updateLayoutUpTree()
  }
}
