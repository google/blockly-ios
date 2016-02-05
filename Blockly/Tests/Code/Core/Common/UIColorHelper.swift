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

class UIColorHelperTest: XCTestCase {

  // MARK: - bky_colorFromRGB

  func testColorFromRGB_valid() {
    assertValuesForColor(UIColor.bky_colorFromRGB("000000")!,
      red: 0x00, green: 0x00, blue: 0x00, alpha: 1.0)
    assertValuesForColor(UIColor.bky_colorFromRGB("ABCDEF")!,
      red: 0xAB, green: 0xCD, blue: 0xEF, alpha: 1.0)
    assertValuesForColor(UIColor.bky_colorFromRGB("123456")!,
      red: 0x12, green: 0x34, blue: 0x56, alpha: 1.0)
    assertValuesForColor(UIColor.bky_colorFromRGB("789000")!,
      red: 0x78, green: 0x90, blue: 0x00, alpha: 1.0)
    assertValuesForColor(UIColor.bky_colorFromRGB("abcdef")!,
      red: 0xab, green: 0xcd, blue: 0xef, alpha: 1.0)
    assertValuesForColor(UIColor.bky_colorFromRGB("#678901")!,
      red: 0x67, green: 0x89, blue: 0x01, alpha: 1.0)
  }

  func testColorFromRGB_invalid() {
    XCTAssertNil(UIColor.bky_colorFromRGB("00000AB"))
    XCTAssertNil(UIColor.bky_colorFromRGB("0000A"))
    XCTAssertNil(UIColor.bky_colorFromRGB("##000000"))
  }

  // MARK - Helper

  func assertValuesForColor(
    color: UIColor, red: Int, green: Int, blue: Int, alpha: Float) {
    var actualRed:CGFloat = 0
    var actualGreen:CGFloat = 0
    var actualBlue:CGFloat = 0
    var actualAlpha:CGFloat = 0

    color.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha)
    XCTAssertEqualWithAccuracy(Float(Double(red)/255.0), Float(actualRed),
      accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(Double(green)/255.0), Float(actualGreen),
      accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(Double(blue)/255.0), Float(actualBlue),
      accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(alpha, Float(actualAlpha), accuracy: TestConstants.ACCURACY_F)
  }
}
