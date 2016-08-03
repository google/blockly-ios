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
public class FieldDateLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldDate` that backs this layout
  public let fieldDate: FieldDate

  /// The value that should be used when rendering this layout
  public var textValue: String {
    return _dateFormatter.stringFromDate(fieldDate.date)
  }

  // Formatter used to generate `self.textValue`
  private let _dateFormatter: NSDateFormatter = {
    // Format the date based on the user's current locale, in a short style
    // (which is generally numeric)
    let dateFormatter = NSDateFormatter()
    dateFormatter.locale = NSLocale.currentLocale()
    dateFormatter.dateStyle = .ShortStyle
    return dateFormatter
  }()

  // MARK: - Initializers

  public init(fieldDate: FieldDate, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldDate = fieldDate
    super.init(field: fieldDate, engine: engine, measurer: measurer)

    fieldDate.delegate = self
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  public override func didUpdateField(field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Updates `self.fieldDate` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - Parameter date: The value used to update `self.fieldDate`.
   */
  public func updateDate(date: NSDate) {
    // Setting to a new date automatically fires a listener to update the layout
    fieldDate.date = date
  }
}
