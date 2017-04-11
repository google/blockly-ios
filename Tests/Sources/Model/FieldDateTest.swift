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

@testable import Blockly
import XCTest

class FieldDateTest: XCTestCase {

  // MARK: - Internal static methods

  func testParseDate_validDates() {
    var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
    calendar.timeZone = TimeZone.autoupdatingCurrent
    var date: Date
    var components: DateComponents

    date = FieldDate.dateFromString("2000-01-01")!
    components = calendar.dateComponents([.year, .month, .day], from: date)
    XCTAssertEqual(2000, components.year)
    XCTAssertEqual(1, components.month)
    XCTAssertEqual(1, components.day)

    date = FieldDate.dateFromString("2020-02-29")!
    components = calendar.dateComponents([.year, .month, .day], from: date)
    XCTAssertEqual(2020, components.year)
    XCTAssertEqual(2, components.month)
    XCTAssertEqual(29, components.day)

    date = FieldDate.dateFromString("2112-12-12")!
    components = calendar.dateComponents([.year, .month, .day], from: date)
    XCTAssertEqual(2112, components.year)
    XCTAssertEqual(12, components.month)
    XCTAssertEqual(12, components.day)
  }

  func testParseDate_invalidDates() {
    XCTAssertNil(FieldDate.dateFromString("2015-02-29"))
    XCTAssertNil(FieldDate.dateFromString("1900-04-31"))
    XCTAssertNil(FieldDate.dateFromString("2015-6-01"))
    XCTAssertNil(FieldDate.dateFromString("2015-10-1"))
    XCTAssertNil(FieldDate.dateFromString("11-11-11"))
    XCTAssertNil(FieldDate.dateFromString("2015-31-01"))
    XCTAssertNil(FieldDate.dateFromString("20150131"))
    XCTAssertNil(FieldDate.dateFromString(""))
  }
}
