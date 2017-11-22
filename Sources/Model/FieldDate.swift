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
An input field for picking a date.
*/
@objc(BKYFieldDate)
@objcMembers public final class FieldDate: Field {
  /// The date format to use for serialization purposes
  fileprivate static let DATE_FORMAT = "yyyy-MM-dd"

  // MARK: - Properties

  /// The `Date` value of this field.
  public var date: Date {
    didSet {
      if self.editable {
        // Normalize the new date
        self.date = FieldDate.normalizeDate(self.date)
      } else {
        // Revert the change
        self.date = oldValue
      }

      if self.date.timeIntervalSince1970 != oldValue.timeIntervalSince1970 {
        notifyDidUpdateField()
      }
    }
  }

  // MARK: - Initializers


  /**
   Initializes the date field.

   - parameter name: The name of this field.
   - parameter date: The initial `Date` to set for this field.
   */
  public init(name: String, date: Date) {
    self.date = FieldDate.normalizeDate(date)
    super.init(name: name)
  }

  /**
  Initializes for the date field.

  - parameter name: The name of this field.
  - parameter stringDate: String of the format "yyyy-MM-dd". If the string couldn't be parsed into a
  valid date, the current date is used instead.
  */
  public convenience init(name: String, stringDate: String) {
    self.init(
      name: name,
      date: FieldDate.dateFromString(stringDate) ?? Date())
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldDate(name: name, date: date)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    if let date = FieldDate.dateFromString(text) {
      self.date = date
    } else {
      throw BlocklyError(.xmlParsing,
        "Could not parse '\(text)' into a date. The format of the date must be 'yyyy-MM-dd'.")
    }
  }

  public override func serializedText() throws -> String? {
    return FieldDate.stringFromDate(self.date)
  }

  // MARK: - Public

  /**
  Sets self.date based on a date string.

  - parameter stringDate: String of the format "yyyy-MM-dd". If the string could not be parsed into
  a valid date, self.date is not changed.
  */
  public func setDateFromString(_ stringDate: String) {
    if let date = FieldDate.dateFromString(stringDate) {
      self.date = date
    }
  }

  // MARK: - Internal - For testing only

  /**
  Parses a string of the format "yyyy-MM-dd".
  */
  internal class func dateFromString(_ string: String) -> Date? {
    if (string.count != 10) {
      return nil
    }
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone.autoupdatingCurrent
    dateFormatter.dateFormat = FieldDate.DATE_FORMAT
    return dateFormatter.date(from: string)
  }

  /**
   Returns a string representation of a date in the format "yyyy-MM-dd".

   - parameter date: A `Date`.
   - returns: A string representation of `date` in the format "yyyy-MM-dd", using the user's
   current timezone.
   */
  internal class func stringFromDate(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone.autoupdatingCurrent
    dateFormatter.dateFormat = FieldDate.DATE_FORMAT
    return dateFormatter.string(from: date)
  }

  /**
  Normalizes a given date by setting it to 00:00:00:000 of the current timezone
  (NSTimeZone.localTimeZone).
  */
  internal class func normalizeDate(_ date: Date) -> Date {
    let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
    let components = (calendar as NSCalendar).components([.year, .month, .day], from: date)

    var localCalendar = Calendar(identifier: Calendar.Identifier.gregorian)
    localCalendar.timeZone = TimeZone.autoupdatingCurrent

    if let newDate = localCalendar.date(from: components) {
      return newDate
    } else {
      return date
    }
  }
}
