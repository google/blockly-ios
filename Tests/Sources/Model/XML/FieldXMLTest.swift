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
import AEXML

class FieldXMLTest: XCTestCase {

  // MARK: - XML Serialization Tests

  func testSerializeXML_FieldAngle() {
    let field = FieldAngle(name: "a_field", angle: 300)
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">300</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("300", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldCheckbox() {
    let field = FieldCheckbox(name: "a_field", checked: false)
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">false</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("FALSE", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldColor() {
    let field = FieldColor(name: "a_field", color: UIColor.red)
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">#FF0000</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("#ff0000", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldDate() {
    let field = FieldDate(name: "a_field", stringDate: "1970-01-01")
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">#FF0000</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("1970-01-01", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldDropdown() {
    let field = try! FieldDropdown(name: "a_field",
      displayNames: ["Test 1", "Test 2"], values: ["Value 1", "Value 2"], selectedIndex: 1)
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">Value 2</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("Value 2", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldImage() {
    let field = FieldImage(
      name: "a_field",
      imageLocation: "some_image.png",
      size: WorkspaceSize.zero,
      altText: "",
      flipRtl: false)
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: nil
    XCTAssertNil(fieldXML)
  }

  func testSerializeXML_FieldInput() {
    let field = FieldInput(name: "a_field", text: "some input")
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">some input</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("some input", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldLabel() {
    let field = FieldLabel(name: "a_field", text: "some label")
    let fieldXML = try! field.toXMLElement()

    // Expected: nil
    XCTAssertNil(fieldXML)
  }

  func testSerializeXML_FieldNumber() {
    let field = FieldNumber(name: "a_field", value: -30.50)
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">-30.5</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("-30.5", fieldXML?.value) // The trailing "0" should be chopped off
    XCTAssertEqual(0, fieldXML?.children.count)
  }

  func testSerializeXML_FieldVariable() {
    let field = FieldVariable(name: "a_field", variable: "variableName")
    let fieldXML = BKYAssertDoesNotThrow { try field.toXMLElement() }

    // Expected: <field name="a_field">variableName</field>
    XCTAssertNotNil(fieldXML)
    XCTAssertEqual("field", fieldXML?.name)
    XCTAssertEqual(1, fieldXML?.attributes.count)
    XCTAssertEqual("a_field", fieldXML?.attributes["name"])
    XCTAssertEqual("variableName", fieldXML?.value)
    XCTAssertEqual(0, fieldXML?.children.count)
  }
}
