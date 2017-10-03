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

class BlockJSONTest: XCTestCase {

  // MARK: - blockFromJSON

  func testBlockFromJSON_allFieldsSet() {
    let testBundle = Bundle(for: type(of: self).self)
    let path = testBundle.path(forResource: "block_json_test", ofType: "json")
    let workspace = Workspace()

    var block: Block
    do {
      let jsonString = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
      let json = try JSONHelper.makeJSONDictionary(string: jsonString)
      block = try Block.makeBuilder(json: json).makeBlock()
      try! workspace.addBlockTree(block)
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("block_id_1", block.name)
    XCTAssertEqual(
      CGFloat(135.0 / 360.0), block.color.bky_hsba().hue, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(true, block.inputsInline)
    XCTAssertEqual("Click me", block.tooltip)
    XCTAssertEqual("http://www.example.com/", block.helpURL)
    XCTAssertEqual(3, block.inputs.count)
    XCTAssertNotNil(block.outputConnection)
    XCTAssertNotNil(block.outputConnection?.typeChecks)
    XCTAssertEqual(["Number", "String"], (block.outputConnection?.typeChecks)!)

    // -- Input Value --
    let input0 = block.inputs[0]
    XCTAssertEqual(Input.InputType.value, input0.type)
    XCTAssertEqual("VALUE INPUT", input0.name)
    XCTAssertEqual(Input.Alignment.center, input0.alignment)
    XCTAssertEqual(9, input0.fields.count) // 7 argument fields + 2 string labels

    // Image
    guard let fieldImage = input0.fields[0] as? FieldImage else {
      XCTFail("input[0].fields[0] is not a FieldImage")
      return
    }
    XCTAssertEqual("http://33.media.tumblr.com/tumblr_lhtb1e4oc11qhp8pjo1_400.gif",
                   fieldImage.imageLocation)
    XCTAssertEqual(100, fieldImage.size.width)
    XCTAssertEqual(100, fieldImage.size.height)
    XCTAssertEqual("Cool Dance!", fieldImage.altText)
    XCTAssertEqual(true, fieldImage.flipRtl)

    // Variable
    guard let fieldVariable = input0.fields[1] as? FieldVariable else {
      XCTFail("input[0].fields[1] is not a FieldVariable")
      return
    }
    XCTAssertEqual("!@#$%^&*()-={}:/.,\"'`", fieldVariable.name)
    XCTAssertEqual("A variable", fieldVariable.variable)

    // Color
    guard let fieldColor = input0.fields[2] as? FieldColor else {
      XCTFail("input[0].fields[2] is not a FieldColor")
      return
    }
    XCTAssertEqual("Colour", fieldColor.name)
    var red:CGFloat = 0
    var green:CGFloat = 0
    var blue:CGFloat = 0
    var alpha:CGFloat = 0
    fieldColor.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    XCTAssertEqual(Float(3.0/255.0), Float(red), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqual(Float(154.0/255.0), Float(green), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqual(Float(223.0/255.0), Float(blue), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqual(Float(1.0), Float(alpha), accuracy: TestConstants.ACCURACY_F)

    // Angle
    guard let fieldAngle = input0.fields[3] as? FieldAngle else {
      XCTFail("input[0].fields[3] is not a FieldAngle")
      return
    }
    XCTAssertEqual("Angle", fieldAngle.name)
    XCTAssertEqual(180, fieldAngle.angle)

    // Input
    guard let fieldInput = input0.fields[4] as? FieldInput else {
      XCTFail("input[0].fields[4] is not a FieldAngle")
      return
    }
    XCTAssertEqual("Input", fieldInput.name)
    XCTAssertEqual("🍅 🍆 🌽 🍠 🍇 🍈 🍉 🍊 🍋 🍌 🍍", fieldInput.text)

    // "for each" text
    guard let fieldLabel0 = input0.fields[5] as? FieldLabel else {
      XCTFail("input[0].fields[5] is not a FieldLabel")
      return
    }
    XCTAssertEqual("", fieldLabel0.name)
    XCTAssertEqual("for each", fieldLabel0.text)

    // Checkbox
    guard let fieldCheckbox = input0.fields[6] as? FieldCheckbox else {
      XCTFail("input[0].fields[6] is not a FieldCheckbox")
      return
    }
    XCTAssertEqual("☑", fieldCheckbox.name)
    XCTAssertEqual(false, fieldCheckbox.checked)

    // Date
    guard let fieldDate = input0.fields[7] as? FieldDate else {
      XCTFail("input[0].fields[7] is not a FieldDate")
      return
    }
    XCTAssertEqual("Judgment Day", fieldDate.name)
    var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
    calendar.timeZone = TimeZone.autoupdatingCurrent
    XCTAssertEqual(1997, calendar.component(.year, from: fieldDate.date))
    XCTAssertEqual(8, calendar.component(.month, from: fieldDate.date))
    XCTAssertEqual(29, calendar.component(.day, from: fieldDate.date))

    // "in" text
    guard let fieldLabel1 = input0.fields[8] as? FieldLabel else {
      XCTFail("input[0].fields[8] is not a FieldLabel")
      return
    }
    XCTAssertEqual("", fieldLabel1.name)
    XCTAssertEqual("in", fieldLabel1.text)

    // -- Input Statement --
    let input1 = block.inputs[1]
    XCTAssertEqual(Input.InputType.statement, input1.type)
    XCTAssertEqual("STATEMENT input", input1.name)
    XCTAssertEqual(Input.Alignment.right, input1.alignment)
    XCTAssertEqual(1, input1.fields.count) // 1 string label

    // "do" text
    guard let fieldLabel2 = input1.fields[0] as? FieldLabel else {
      XCTFail("input[1].fields[0] is not a FieldLabel")
      return
    }
    XCTAssertEqual("", fieldLabel2.name)
    XCTAssertEqual("do", fieldLabel2.text)

    // -- Dummy Statement --
    let input2 = block.inputs[2]
    XCTAssertEqual(Input.InputType.dummy, input2.type)
    XCTAssertEqual("DUMMY INPUT", input2.name)
    XCTAssertEqual(0, input2.fields.count)

    // -- Style --
    XCTAssertNotNil(block.style.hat)
    XCTAssertEqual(Block.Style.hatCap, block.style.hat)
  }

  // MARK: - tokenizedString

  func testTokenizedString_emptyMessage() {
    let tokens = Block.tokenizedString("")
    XCTAssertEqual(0, tokens.count)
  }

  func testTokenizedString_emojiMessage() {
    let tokens = Block.tokenizedString("👋 %1 🌏")
    XCTAssertEqual(3, tokens.count)
    if tokens.count >= 3 {
      XCTAssertEqual("👋 ", tokens[0] as? String)
      XCTAssertEqual(1, tokens[1] as? Int)
      XCTAssertEqual(" 🌏", tokens[2] as? String)
    }
  }

  func testTokenizedString_simpleMessage() {
    let tokens = Block.tokenizedString("Simple text")
    XCTAssertEqual(1, tokens.count)
    if tokens.count >= 1 {
      XCTAssertEqual("Simple text", tokens[0] as? String)
    }
  }

  func testTokenizedString_complexMessage() {
    let tokens = Block.tokenizedString("  token1%1%%%3another\n%29 😸📺 %1234567890")
    XCTAssertEqual(8, tokens.count)
    if tokens.count >= 8 {
      XCTAssertEqual("  token1", tokens[0] as? String)
      XCTAssertEqual(1, tokens[1] as? Int)
      XCTAssertEqual("%", tokens[2] as? String)
      XCTAssertEqual(3, tokens[3] as? Int)
      XCTAssertEqual("another\n", tokens[4] as? String)
      XCTAssertEqual(29, tokens[5] as? Int)
      XCTAssertEqual(" 😸📺 ", tokens[6] as? String)
      XCTAssertEqual(1234567890, tokens[7] as? Int)
    }
  }

  func testTokenizedString_unescapePercent() {
    let tokens = Block.tokenizedString("blah%blahblah")
    XCTAssertEqual(1, tokens.count)
    if tokens.count >= 1 {
      XCTAssertEqual("blah%blahblah", tokens[0] as? String)
    }
  }

  func testTokenizedString_trailingPercent() {
    let tokens = Block.tokenizedString("%")
    XCTAssertEqual(1, tokens.count)
    if tokens.count >= 1 {
      XCTAssertEqual("%", tokens[0] as? String)
    }
  }
}
