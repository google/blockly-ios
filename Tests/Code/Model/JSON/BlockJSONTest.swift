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
    let testBundle = NSBundle(forClass: self.dynamicType.self)
    let path = testBundle.pathForResource("block_json_test", ofType: "json")
    let workspace = Workspace(isFlyout: false)

    var block: Block
    do {
      let jsonString = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
      let json = try NSJSONSerialization.bky_JSONDictionaryFromString(jsonString)
      block = try Block.builderFromJSON(json).buildForWorkspace(workspace)
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("block_id_1", block.identifier)
    XCTAssertEqual(135, block.colourHue)
    XCTAssertEqual(true, block.inputsInline)
    XCTAssertEqual("Click me", block.tooltip)
    XCTAssertEqual("http://www.example.com/", block.helpURL)
    XCTAssertEqual(3, block.inputs.count)
    XCTAssertNotNil(block.outputConnection)
    XCTAssertNotNil(block.outputConnection?.typeChecks)
    XCTAssertEqual(["Number", "String"], (block.outputConnection?.typeChecks)!)

    // -- Input Value --
    let input0 = block.inputs[0]
    XCTAssertEqual(Input.InputType.Value, input0.type)
    XCTAssertEqual("VALUE INPUT", input0.name)
    XCTAssertEqual(Input.Alignment.Centre, input0.alignment)
    XCTAssertEqual(9, input0.fields.count) // 7 argument fields + 2 string labels

    // Image
    guard let fieldImage = input0.fields[0] as? FieldImage else {
      XCTFail("input[0].fields[0] is not a FieldImage")
      return
    }
    XCTAssertEqual("http://33.media.tumblr.com/tumblr_lhtb1e4oc11qhp8pjo1_400.gif", fieldImage.imageURL)
    XCTAssertEqual(100, fieldImage.size.width)
    XCTAssertEqual(100, fieldImage.size.height)
    XCTAssertEqual("Cool Dance!", fieldImage.altText)

    // Variable
    guard let fieldVariable = input0.fields[1] as? FieldVariable else {
      XCTFail("input[0].fields[1] is not a FieldVariable")
      return
    }
    XCTAssertEqual("!@#$%^&*()-={}:/.,\"'`", fieldVariable.name)
    XCTAssertEqual("A variable", fieldVariable.variable)

    // Colour
    guard let fieldColour = input0.fields[2] as? FieldColour else {
      XCTFail("input[0].fields[2] is not a FieldColour")
      return
    }
    XCTAssertEqual("Colour", fieldColour.name)
    var red:CGFloat = 0
    var green:CGFloat = 0
    var blue:CGFloat = 0
    var alpha:CGFloat = 0
    fieldColour.colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    XCTAssertEqualWithAccuracy(Float(3.0/255.0), Float(red), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(154.0/255.0), Float(green), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(223.0/255.0), Float(blue), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(1.0), Float(alpha), accuracy: TestConstants.ACCURACY_F)

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
    let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    calendar.timeZone = NSTimeZone.localTimeZone()
    let components = calendar.components([.Year, .Month, .Day], fromDate: fieldDate.date)
    XCTAssertEqual(1997, components.year)
    XCTAssertEqual(8, components.month)
    XCTAssertEqual(29, components.day)

    // "in" text
    guard let fieldLabel1 = input0.fields[8] as? FieldLabel else {
      XCTFail("input[0].fields[8] is not a FieldLabel")
      return
    }
    XCTAssertEqual("", fieldLabel1.name)
    XCTAssertEqual("in", fieldLabel1.text)

    // -- Input Statement --
    let input1 = block.inputs[1]
    XCTAssertEqual(Input.InputType.Statement, input1.type)
    XCTAssertEqual("STATEMENT input", input1.name)
    XCTAssertEqual(Input.Alignment.Right, input1.alignment)
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
    XCTAssertEqual(Input.InputType.Dummy, input2.type)
    XCTAssertEqual("DUMMY INPUT", input2.name)
    XCTAssertEqual(0, input2.fields.count)
  }

  // MARK: - tokenizeMessage

  func testTokenizeMessage_emptyMessage() {
    let tokens = Block.tokenizeMessage("")
    XCTAssertEqual(0, tokens.count)
  }

  func testTokenizeMessage_emojiMessage() {
    let tokens = Block.tokenizeMessage("👋 %1 🌏")
    XCTAssertEqual(["👋 ", 1, " 🌏"], tokens)
  }

  func testTokenizeMessage_simpleMessage() {
    let tokens = Block.tokenizeMessage("Simple text")
    XCTAssertEqual(["Simple text"], tokens)
  }

  func testTokenizeMessage_complexMessage() {
    let tokens = Block.tokenizeMessage("  token1%1%%%3another\n%29 😸📺 %1234567890")
    XCTAssertEqual(["  token1", 1, "%", 3, "another\n", 29, " 😸📺 ", 1234567890], tokens)
  }

  func testTokenizeMessage_unescapePercent() {
    let tokens = Block.tokenizeMessage("blah%blahblah")
    XCTAssertEqual(["blah%blahblah"], tokens)
  }

  func testTokenizeMessage_trailingPercent() {
    let tokens = Block.tokenizeMessage("%")
    XCTAssertEqual(["%"], tokens)
  }
}
