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

  private var workspace: Workspace!

  // MARK: - Super

  override func setUp() {
    self.workspace = Workspace()
  }

  // MARK: - fieldFromJSON - Angle

  func testFieldFromJSON_AngleValid() {
    let json = ["type": "field_angle", "name": "FIELD ANGLE", "angle": 880]
    let field: FieldAngle
    do {
      if let fieldAngle = try Field.fieldFromJSON(json) as? FieldAngle {
        field = fieldAngle
      } else {
        XCTFail("Could not parse json into a FieldAngle")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("FIELD ANGLE", field.name)
    XCTAssertEqual(160, field.angle)
  }

  // MARK: - fieldFromJSON - Checkbox

  func testFieldFromJSON_CheckboxValid() {
    let json = ["type": "field_checkbox", "name": "Something", "checked": true]
    let field: FieldCheckbox
    do {
      if let fieldCheckbox = try Field.fieldFromJSON(json) as? FieldCheckbox {
        field = fieldCheckbox
      } else {
        XCTFail("Could not parse json into a FieldColour")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("Something", field.name)
    XCTAssertEqual(true, field.checked)
  }

  // MARK: - fieldFromJSON - Colour

  func testFieldFromJSON_ColourValid() {
    let json = ["type": "field_colour", "name": "ABC", "colour": "#00fFAa"]
    let field: FieldColour
    do {
      if let fieldColour = try Field.fieldFromJSON(json) as? FieldColour {
        field = fieldColour
      } else {
        XCTFail("Could not parse json into a FieldColour")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("ABC", field.name)
    var red:CGFloat = 0
    var green:CGFloat = 0
    var blue:CGFloat = 0
    var alpha:CGFloat = 0
    field.colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    XCTAssertEqualWithAccuracy(Float(0.0/255.0), Float(red), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(255.0/255.0), Float(green), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(170.0/255.0), Float(blue), accuracy: TestConstants.ACCURACY_F)
    XCTAssertEqualWithAccuracy(Float(1.0), Float(alpha), accuracy: TestConstants.ACCURACY_F)
  }

  // MARK: - fieldFromJSON - Date

  func testFieldFromJSON_DateValid() {
    let json = ["type": "field_date", "name": "ABC", "date": "2016-02-29"]
    let field: FieldDate
    do {
      if let fieldDate = try Field.fieldFromJSON(json) as? FieldDate {
        field = fieldDate
      } else {
        XCTFail("Could not parse json into a FieldDate")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("ABC", field.name)
    let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    calendar.timeZone = NSTimeZone.localTimeZone()
    let components = calendar.components([.Year, .Month, .Day], fromDate: field.date)
    XCTAssertEqual(2016, components.year)
    XCTAssertEqual(2, components.month)
    XCTAssertEqual(29, components.day)
  }

  // MARK: - fieldFromJSON - Dropdown

  func testFieldFromJSON_DropdownValid() {
    let json = [
      "type": "field_dropdown",
      "name": "Dropdown",
      "options": [["Option 1", "VALUE 1"], ["Option 2", "VALUE 2"], ["Option 3", "VALUE 3"]],
    ]
    let field: FieldDropdown
    do {
      if let fieldDropdown = try Field.fieldFromJSON(json) as? FieldDropdown {
        field = fieldDropdown
      } else {
        XCTFail("Could not parse json into a FieldDropdown")
        return
      }
    } catch let error as NSError {
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
    ]
    let field: FieldImage
    do {
      if let fieldImage = try Field.fieldFromJSON(json) as? FieldImage {
        field = fieldImage
      } else {
        XCTFail("Could not parse json into a FieldImage")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("Image", field.name)
    XCTAssertEqual(100000, field.size.height)
    XCTAssertEqual(200000, field.size.width)
    XCTAssertEqual("http://media.firebox.com/pic/p5294_column_grid_12.jpg", field.imageURL)
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
      if let fieldInput = try Field.fieldFromJSON(json) as? FieldInput {
        field = fieldInput
      } else {
        XCTFail("Could not parse json into a FieldInput")
        return
      }
    } catch let error as NSError {
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
      if let fieldLabel = try Field.fieldFromJSON(json) as? FieldLabel {
        field = fieldLabel
      } else {
        XCTFail("Could not parse json into a FieldLabel")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("label", field.name)
    XCTAssertEqual("some label", field.text)
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
      if let fieldVariable = try Field.fieldFromJSON(json) as? FieldVariable {
        field = fieldVariable
      } else {
        XCTFail("Could not parse json into a FieldVariable")
        return
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
      return
    }

    XCTAssertEqual("variable", field.name)
    XCTAssertEqual("some variable", field.variable)
  }
}
