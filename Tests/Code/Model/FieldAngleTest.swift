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

class FieldAngleTest: XCTestCase {

  // MARK: - Internal static methods

  func testNormalizeAngle() {
    XCTAssertEqual(0, FieldAngle.normalizeAngle(0))
    XCTAssertEqual(200, FieldAngle.normalizeAngle(200))
    XCTAssertEqual(360, FieldAngle.normalizeAngle(360))
    XCTAssertEqual(1, FieldAngle.normalizeAngle(361))
    XCTAssertEqual(359, FieldAngle.normalizeAngle(-1))
    XCTAssertEqual(0, FieldAngle.normalizeAngle(720))
    XCTAssertEqual(83, FieldAngle.normalizeAngle(80003))
    XCTAssertEqual(277, FieldAngle.normalizeAngle(-80003))
  }
}
