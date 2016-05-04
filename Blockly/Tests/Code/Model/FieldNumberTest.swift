/*
 * Copyright 2016 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License")
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

class FieldNumberTest: XCTestCase {

  private var fieldNumber: FieldNumber!

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    fieldNumber = FieldNumber(name: "number", value: 0)
  }

  // MARK: - Tests

  func testConstrainedRangeSuccess() {
    let MIN = -100.0
    let MAX = 100.0
    let PRECISION = 0.1

    try! fieldNumber.setConstraints(minimum: MIN, maximum: MAX, precision: PRECISION)
    XCTAssertEqual(MIN, fieldNumber.minimumValue)
    XCTAssertEqual(MAX, fieldNumber.maximumValue)
    XCTAssertEqual(PRECISION, fieldNumber.precision)

    // Normal assignments
    fieldNumber.value = 3.0
    XCTAssertEqual(3.0, fieldNumber.value)
    fieldNumber.value = 0.2
    XCTAssertEqual(0.2, fieldNumber.value)
    fieldNumber.value = 0.09
    XCTAssertEqual(0.1, fieldNumber.value, "Rounded 0.09 to precision.")
    fieldNumber.value = 0.0
    XCTAssertEqual(0.0, fieldNumber.value)
    fieldNumber.value = -0.1
    XCTAssertEqual(-0.1, fieldNumber.value)
    fieldNumber.value = -0.1
    XCTAssertEqual(-0.1, fieldNumber.value)
    fieldNumber.value = -0.29
    XCTAssertEqual(-0.3, fieldNumber.value)

    fieldNumber.value = MIN + PRECISION
    XCTAssertTrue(MIN < fieldNumber.value)
    fieldNumber.value = MAX - PRECISION
    XCTAssertTrue(fieldNumber.value < MAX)

    fieldNumber.value = MIN
    XCTAssertEqual(MIN, fieldNumber.value)
    fieldNumber.value = MAX
    XCTAssertEqual(MAX, fieldNumber.value)

    fieldNumber.value = MIN - PRECISION
    XCTAssertEqual(MIN, fieldNumber.value)
    fieldNumber.value = MAX + PRECISION
    XCTAssertEqual(MAX, fieldNumber.value)

    fieldNumber.value = MIN - 1e100
    XCTAssertEqual(MIN, fieldNumber.value)
    fieldNumber.value = MAX + 1e100
    XCTAssertEqual(MAX, fieldNumber.value)
  }

  func testSetConstraints_IllegalArguments() {
    do {
      try fieldNumber.setConstraints(minimum: Double.NaN, maximum: 1.0, precision: 0.1)
      XCTFail("NaN minimum is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: Double.infinity, maximum: 1.0, precision: 0.1)
      XCTFail("`Double.infinity` minimum is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: -Double.infinity, maximum: 1.0, precision: 0.1)
      XCTFail("Negative `Double.infinity` minimum is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: -1.0, maximum: Double.NaN, precision: 0.1)
      XCTFail("NaN maximum is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: -1.0, maximum: Double.infinity, precision: 0.1)
      XCTFail("`Double.infinity` maximum is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: -1.0, maximum: -Double.infinity, precision: 0.1)
      XCTFail("Negative `Double.infinity` maximum is not allowed.")
    } catch {
      // Expected
    }


    do {
      try fieldNumber.setConstraints(minimum: -1.0, maximum: 1.0, precision: Double.NaN)
      XCTFail("NaN precision is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: -1.0, maximum: 1.0, precision: Double.infinity)
      XCTFail("`Double.infinity` precision is not allowed.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: -1.0, maximum: 1.0, precision: -Double.infinity)
      XCTFail("Negative `Double.infinity` precision is not allowed.")
    } catch {
      // Expected
    }
  }

  func testSetConstraints_InvalidConstraintPairs() {
    do {
      try fieldNumber.setConstraints(minimum: 1.0, maximum: -1.0)
      XCTFail("min must be less than max.")
    } catch {
      // Expected
    }

    do {
      try fieldNumber.setConstraints(minimum: 1.0, maximum: 4.0, precision: 5.0)
      XCTFail("Check for no valid values with given constraints.")
    } catch {
      // Expected
    }
  }

  func testDecimalPrecisionLessThanOne() {
    let PRECISION = 0.25  // Two significant digits
    try! fieldNumber.setConstraints(precision: PRECISION)

    XCTAssertFalse(fieldNumber.isInteger)

    // Exact values
    fieldNumber.value = 0.0
    XCTAssertEqual(0.0, fieldNumber.value)
    XCTAssertEqual("0.00", fieldNumber.textValue)

    fieldNumber.value = 0.25
    XCTAssertEqual(0.25, fieldNumber.value)
    XCTAssertEqual("0.25", fieldNumber.textValue)

    fieldNumber.value = 1.0
    XCTAssertEqual(1.0, fieldNumber.value)
    XCTAssertEqual("1.00", fieldNumber.textValue)

    fieldNumber.value = 1.25
    XCTAssertEqual(1.25, fieldNumber.value)
    XCTAssertEqual("1.25", fieldNumber.textValue)

    fieldNumber.value = 2.50
    XCTAssertEqual(2.5, fieldNumber.value)
    XCTAssertEqual("2.50", fieldNumber.textValue)

    fieldNumber.value = 25
    XCTAssertEqual(25.0, fieldNumber.value)
    XCTAssertEqual("25.00", fieldNumber.textValue)

    fieldNumber.value = -0.25
    XCTAssertEqual(-0.25, fieldNumber.value)
    XCTAssertEqual("-0.25", fieldNumber.textValue)

    fieldNumber.value = -1.0
    XCTAssertEqual(-1.0, fieldNumber.value)
    XCTAssertEqual("-1.00", fieldNumber.textValue)

    fieldNumber.value = -1.25
    XCTAssertEqual(-1.25, fieldNumber.value)
    XCTAssertEqual("-1.25", fieldNumber.textValue)

    fieldNumber.value = -2.50
    XCTAssertEqual(-2.5, fieldNumber.value)
    XCTAssertEqual("-2.50", fieldNumber.textValue)

    fieldNumber.value = -25
    XCTAssertEqual(-25.0, fieldNumber.value)
    XCTAssertEqual("-25.00", fieldNumber.textValue)

    // Rounded Values
    fieldNumber.value = 0.2
    XCTAssertEqual(0.25, fieldNumber.value)

    fieldNumber.value = 0.9
    XCTAssertEqual(1.0, fieldNumber.value)

    fieldNumber.value = 1.1
    XCTAssertEqual(1.0, fieldNumber.value)

    fieldNumber.value = 1.2
    XCTAssertEqual(1.25, fieldNumber.value)

    fieldNumber.value = 1.3
    XCTAssertEqual(1.25, fieldNumber.value)
  }

  func testIntegerPrecisionOne() {
    let PRECISION = 1.0
    try! fieldNumber.setConstraints(precision: PRECISION)

    XCTAssertTrue(fieldNumber.isInteger)

    // Exact values
    fieldNumber.value = 0.0
    XCTAssertEqual(0.0, fieldNumber.value)
    XCTAssertEqual("0", fieldNumber.textValue)

    fieldNumber.value = 1.0
    XCTAssertEqual(1.0, fieldNumber.value)
    XCTAssertEqual("1", fieldNumber.textValue)

    fieldNumber.value = 2.0
    XCTAssertEqual(2.0, fieldNumber.value)
    XCTAssertEqual("2", fieldNumber.textValue)

    fieldNumber.value = 7.0
    XCTAssertEqual(7.0, fieldNumber.value)
    XCTAssertEqual("7", fieldNumber.textValue)

    fieldNumber.value = 10.0
    XCTAssertEqual(10.0, fieldNumber.value)
    XCTAssertEqual("10", fieldNumber.textValue)

    fieldNumber.value = 100.0
    XCTAssertEqual(100.0, fieldNumber.value)
    XCTAssertEqual("100", fieldNumber.textValue)

    fieldNumber.value = 1000000.0
    XCTAssertEqual(1000000.0, fieldNumber.value)
    XCTAssertEqual("1000000", fieldNumber.textValue)

    fieldNumber.value = -1.0
    XCTAssertEqual(-1.0, fieldNumber.value)
    XCTAssertEqual("-1", fieldNumber.textValue)

    fieldNumber.value = -2.0
    XCTAssertEqual(-2.0, fieldNumber.value)
    XCTAssertEqual("-2", fieldNumber.textValue)

    fieldNumber.value = -7.0
    XCTAssertEqual(-7.0, fieldNumber.value)
    XCTAssertEqual("-7", fieldNumber.textValue)

    fieldNumber.value = -10.0
    XCTAssertEqual(-10.0, fieldNumber.value)
    XCTAssertEqual("-10", fieldNumber.textValue)

    fieldNumber.value = -100.0
    XCTAssertEqual(-100.0, fieldNumber.value)
    XCTAssertEqual("-100", fieldNumber.textValue)

    fieldNumber.value = -1000000.0
    XCTAssertEqual(-1000000.0, fieldNumber.value)
    XCTAssertEqual("-1000000", fieldNumber.textValue)


    // Rounded Values
    fieldNumber.value = 0.2
    XCTAssertEqual(0.0, fieldNumber.value)

    fieldNumber.value = 0.499999
    XCTAssertEqual(0.0, fieldNumber.value)

    fieldNumber.value = 0.5
    XCTAssertEqual(1.0, fieldNumber.value)

    fieldNumber.value = 1.1
    XCTAssertEqual(1.0, fieldNumber.value)

    fieldNumber.value = 99.9999
    XCTAssertEqual(100.0, fieldNumber.value)

    fieldNumber.value = -0.2
    XCTAssertEqual(0.0, fieldNumber.value)

    fieldNumber.value = -0.5
    XCTAssertEqual(-1.0, fieldNumber.value)

    fieldNumber.value = -0.501
    XCTAssertEqual(-1.0, fieldNumber.value)

    fieldNumber.value = -1.1
    XCTAssertEqual(-1.0, fieldNumber.value)

    fieldNumber.value = -99.9999
    XCTAssertEqual(-100.0, fieldNumber.value)
  }

  func testIntegerPrecisionTwo() {
    let PRECISION = 2.0
    try! fieldNumber.setConstraints(precision: PRECISION)

    XCTAssertTrue(fieldNumber.isInteger)

    // Exact values
    fieldNumber.value = 0.0
    XCTAssertEqual(0.0, fieldNumber.value)
    XCTAssertEqual("0", fieldNumber.textValue)

    fieldNumber.value = 2.0
    XCTAssertEqual(2.0, fieldNumber.value)
    XCTAssertEqual("2", fieldNumber.textValue)

    fieldNumber.value = 8.0
    XCTAssertEqual(8.0, fieldNumber.value)
    XCTAssertEqual("8", fieldNumber.textValue)

    fieldNumber.value = 10.0
    XCTAssertEqual(10.0, fieldNumber.value)
    XCTAssertEqual("10", fieldNumber.textValue)

    fieldNumber.value = -2.0
    XCTAssertEqual(-2.0, fieldNumber.value)
    XCTAssertEqual("-2", fieldNumber.textValue)

    fieldNumber.value = -8.0
    XCTAssertEqual(-8.0, fieldNumber.value)
    XCTAssertEqual("-8", fieldNumber.textValue)

    // Rounded Values
    fieldNumber.value = 0.2
    XCTAssertEqual(0.0, fieldNumber.value)

    fieldNumber.value = 1.9
    XCTAssertEqual(2.0, fieldNumber.value)

    fieldNumber.value = 0.999
    XCTAssertEqual(0.0, fieldNumber.value)

    fieldNumber.value = 1.0
    XCTAssertEqual(2.0, fieldNumber.value)

    fieldNumber.value = 3.0
    XCTAssertEqual(4.0, fieldNumber.value)

    fieldNumber.value = -0.2
    XCTAssertEqual(0.0, fieldNumber.value)

    fieldNumber.value = -1.9
    XCTAssertEqual(-2.0, fieldNumber.value)
    
    fieldNumber.value = -1.0
    XCTAssertEqual(-2.0, fieldNumber.value)
    
    fieldNumber.value = -1.001
    XCTAssertEqual(-2.0, fieldNumber.value)
  }
  
  func testSetFromLocalizedText_ExponentNotation() {
    // Use the default constraints
    try! fieldNumber.setConstraints(minimum: nil, maximum: nil, precision: nil)

    try! fieldNumber.setValueFromLocalizedText("123e4")
    XCTAssertEqual(1230000, fieldNumber.value)

    try! fieldNumber.setValueFromLocalizedText("1.23e4")
    XCTAssertEqual(12300, fieldNumber.value)

    try! fieldNumber.setValueFromLocalizedText("-1.23e4")
    XCTAssertEqual(-12300, fieldNumber.value)

    try! fieldNumber.setValueFromLocalizedText("123e-4")
    XCTAssertEqual(0.0123, fieldNumber.value)

    try! fieldNumber.setValueFromLocalizedText("1.23e-4")
    XCTAssertEqual(0.000123, fieldNumber.value)
  }
}
