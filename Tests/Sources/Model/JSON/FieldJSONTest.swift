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

class FieldJSONTest: XCTestCase {

  var workspace: Workspace!

  // MARK: - Super

  override func setUp() {
    self.workspace = Workspace()
  }

  // MARK: - fieldFromJSON - Angle

  func testFieldFromJSON_AngleValid() {
    let json = ["type": "field_angle", "name": "FIELD ANGLE", "angle": 880] as [String : Any]
    let field: FieldAngle
    do {
      if let fieldAngle = try Field.makeField(json: json) as? FieldAngle {
        field = fieldAngle
      } else {
        XCTFail("Could not parse json into a FieldAngle")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("FIELD ANGLE", field.name)
    XCTAssertEqual(880, field.angle)
  }

  // MARK: - fieldFromJSON - Checkbox

  func testFieldFromJSON_CheckboxValid() {
    let json = ["type": "field_checkbox", "name": "Something", "checked": true] as [String : Any]
    let field: FieldCheckbox
    do {
      if let fieldCheckbox = try Field.makeField(json: json) as? FieldCheckbox {
        field = fieldCheckbox
      } else {
        XCTFail("Could not parse json into a FieldColor")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("Something", field.name)
    XCTAssertEqual(true, field.checked)
  }

  // MARK: - fieldFromJSON - Color

  func testFieldFromJSON_ColorValid() {
    let json = ["type": "field_colour", "name": "ABC", "colour": "#00fFAa"]
    let field: FieldColor
    do {
      if let fieldColor = try Field.makeField(json: json) as? FieldColor {
        field = fieldColor
      } else {
        XCTFail("Could not parse json into a FieldColor")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("ABC", field.name)
    var red:CGFloat = 0
    var green:CGFloat = 0
    var blue:CGFloat = 0
    var alpha:CGFloat = 0
    field.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    XCTAssertEqual(Float(0.0/255.0), Float(red), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqual(Float(255.0/255.0), Float(green), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqual(Float(170.0/255.0), Float(blue), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqual(Float(1.0), Float(alpha), accuracy: TestConstants.ACCURACY_F)
  }

  // MARK: - fieldFromJSON - Date

  func testFieldFromJSON_DateValid() {
    let json = ["type": "field_date", "name": "ABC", "date": "2016-02-29"]
    let field: FieldDate
    do {
      if let fieldDate = try Field.makeField(json: json) as? FieldDate {
        field = fieldDate
      } else {
        XCTFail("Could not parse json into a FieldDate")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("ABC", field.name)
    var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
    calendar.timeZone = TimeZone.autoupdatingCurrent
    XCTAssertEqual(2016, calendar.component(.year, from: field.date))
    XCTAssertEqual(2, calendar.component(.month, from: field.date))
    XCTAssertEqual(29, calendar.component(.day, from: field.date))
  }

  // MARK: - fieldFromJSON - Dropdown

  func testFieldFromJSON_DropdownValid() {
    let json = [
      "type": "field_dropdown",
      "name": "Dropdown",
      "options": [["Option 1", "VALUE 1"], ["Option 2", "VALUE 2"], ["Option 3", "VALUE 3"]],
    ] as [String : Any]
    let field: FieldDropdown
    do {
      if let fieldDropdown = try Field.makeField(json: json) as? FieldDropdown {
        field = fieldDropdown
      } else {
        XCTFail("Could not parse json into a FieldDropdown")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("Dropdown", field.name)
    XCTAssertEqual(3, field.options.count)
    XCTAssertEqual("Option 1", field.options[0].displayName)
    XCTAssertEqual("VALUE 1", field.options[0].value)
    XCTAssertEqual("Option 2", field.options[1].displayName)
    XCTAssertEqual("VALUE 2", field.options[1].value)
    XCTAssertEqual("Option 3", field.options[2].displayName)
    XCTAssertEqual("VALUE 3", field.options[2].value)
  }

  // MARK: - fieldFromJSON - Image

  func testFieldFromJSON_ImageValid() {
    let json = [
      "type": "field_image",
      "name": "Image",
      "height": 100000,
      "width": 200000,
      "src": "http://media.firebox.com/pic/p5294_column_grid_12.jpg",
      "alt": "Unicorn Power",
    ] as [String : Any]
    let field: FieldImage
    do {
      if let fieldImage = try Field.makeField(json: json) as? FieldImage {
        field = fieldImage
      } else {
        XCTFail("Could not parse json into a FieldImage")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("Image", field.name)
    XCTAssertEqual(100000, field.size.height)
    XCTAssertEqual(200000, field.size.width)
    XCTAssertEqual("http://media.firebox.com/pic/p5294_column_grid_12.jpg", field.imageLocation)
    XCTAssertEqual("Unicorn Power", field.altText)
  }

  // MARK: - fieldFromJSON - Input

  func testFieldFromJSON_InputValid() {
    let json = [
      "type": "field_input",
      "name": "input",
      "text": "some text",
    ]
    let field: FieldInput
    do {
      if let fieldInput = try Field.makeField(json: json) as? FieldInput {
        field = fieldInput
      } else {
        XCTFail("Could not parse json into a FieldInput")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("input", field.name)
    XCTAssertEqual("some text", field.text)
  }

  // MARK: - fieldFromJSON - Label

  func testFieldFromJSON_LabelValid() {
    let json = [
      "type": "field_label",
      "name": "label",
      "text": "some label",
    ]
    let field: FieldLabel
    do {
      if let fieldLabel = try Field.makeField(json: json) as? FieldLabel {
        field = fieldLabel
      } else {
        XCTFail("Could not parse json into a FieldLabel")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("label", field.name)
    XCTAssertEqual("some label", field.text)
  }

  // MARK: - fieldFromJSON - Number

  func testFieldFromJSON_NumberValid() {
    let json = [
      "type": "field_number",
      "name": "number",
      "value": -25.30,
      "min": -50,
      "max": 50.500,
      "precision": 0.1,
      ] as [String : Any]
    let field: FieldNumber
    do {
      if let fieldNumber = try Field.makeField(json: json) as? FieldNumber {
        field = fieldNumber
      } else {
        XCTFail("Could not parse json into a FieldNumber")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("number", field.name)
    XCTAssertEqual(-25.30, field.value)
    XCTAssertEqual(-50, field.minimumValue)
    XCTAssertEqual(50.5, field.maximumValue)
    XCTAssertEqual(0.1, field.precision)
  }

  // MARK: - fieldFromJSON - Variable

  func testFieldFromJSON_VariableValid() {
    let json = [
      "type": "field_variable",
      "name": "variable",
      "variable": "some variable",
    ]
    let field: FieldVariable
    do {
      if let fieldVariable = try Field.makeField(json: json) as? FieldVariable {
        field = fieldVariable
      } else {
        XCTFail("Could not parse json into a FieldVariable")
        return
      }
    } catch let error {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("variable", field.name)
    XCTAssertEqual("some variable", field.variable)
  }
}
