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
public class FieldDate: Field {
  // MARK: - Properties

  public var date: NSDate {
    didSet { self.date = FieldDate.normalizeDate(self.date) }
  }

  // MARK: - Initializers

  public init(name: String, date: NSDate) {
    self.date = FieldDate.normalizeDate(date)

    super.init(type: .Date, name: name)
  }

  /**
  Initializer for FieldDate.

  - Parameter name: The name.
  - Parameter stringDate: String of the format "yyyy-MM-dd". If the string couldn't be parsed into a
  valid date, the current date is used instead.
  */
  public convenience init(name: String, stringDate: String) {
    self.init(
      name: name,
      date: FieldDate.dateFromString(stringDate) ?? NSDate())
  }

  // MARK: - Public

  /**
  Sets self.date based on a date string.

  - Parameter stringDate: String of the format "yyyy-MM-dd". If the string could not be parsed into
  a valid date, self.date is not changed.
  */
  public func setDateFromString(stringDate: String) {
    if let date = FieldDate.dateFromString(stringDate) {
      self.date = date
    }
  }

  // MARK: - Internal - For testing only

  /**
  Parses a string of the format "yyyy-MM-dd".
  */
  internal class func dateFromString(string: String) -> NSDate? {
    if (string.characters.count != 10) {
      return nil
    }
    let dateFormatter = NSDateFormatter()
    dateFormatter.timeZone = NSTimeZone.localTimeZone()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.dateFromString(string)
  }

  /**
  Normalizes a given date by setting it to 00:00:00:000 of the current timezone
  (NSTimeZone.localTimeZone).
  */
  internal class func normalizeDate(date: NSDate) -> NSDate {
    let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    let components = calendar.components([.Year, .Month, .Day], fromDate: date)

    let localCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    localCalendar.timeZone = NSTimeZone.localTimeZone()

    if let newDate = localCalendar.dateFromComponents(components) {
      return newDate
    } else {
      return date
    }
  }
}
