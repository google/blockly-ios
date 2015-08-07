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

extension Field {
  // MARK: - Properties

  // JSON parameters
  private static let PARAMETER_ALT_TEXT = "alt"
  private static let PARAMETER_ANGLE = "angle"
  private static let PARAMETER_CHECKED = "checked"
  private static let PARAMETER_COLOUR = "colour"
  private static let PARAMETER_DATE = "date"
  private static let PARAMETER_HEIGHT = "height"
  private static let PARAMETER_IMAGE_URL = "src"
  private static let PARAMETER_NAME = "name"
  private static let PARAMETER_OPTIONS = "options"
  private static let PARAMETER_TEXT = "text"
  private static let PARAMETER_TYPE = "type"
  private static let PARAMETER_VARIABLE = "variable"
  private static let PARAMETER_WIDTH = "width"

  // MARK: - Internal

  /**
  Creates a new |Field| from a JSON dictionary.

  - Parameter json: JSON dictionary
  - Throws:
  |BlockError|: Occurs if malformed JSON data was passed in.
  - Returns: A |Field| instance based on the JSON dictionary, or |nil| if there wasn't sufficient
  data in the dictionary.
  */
  internal static func fieldFromJSON(json: [String: AnyObject]) throws -> Field? {
    guard let type = Field.FieldType(string: (json[PARAMETER_TYPE] as? String ?? "")) else {
      return nil
    }

    switch type {
    case .Angle:
      return FieldAngle(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        angle: (json[PARAMETER_ANGLE] as? Int ?? 90))

    case .Checkbox:
      return FieldCheckbox(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        checked: (json[PARAMETER_CHECKED] as? Bool ?? true))

    case .Colour:
      let colour = UIColor.bky_colorFromRGB(json[PARAMETER_COLOUR] as? String ?? "")
      return FieldColour(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        colour: (colour ?? UIColor.redColor()))

    case .Date:
      return FieldDate(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        stringDate: (json[PARAMETER_DATE] as? String ?? ""))

    case .Dropdown:
      // Options should be an array of string arrays.
      // eg. [["Name 1", "Value 1"], ["Name 2", "Value 2"]]
      let options = json[PARAMETER_OPTIONS] as? Array<[String]> ?? []

      // Check that all arrays contain exactly two values and that the second value is not empty
      if (options.filter { ($0.count != 2) || ($0[1] == "") }.count > 0) {
        throw BlockError(.InvalidBlockDefinition, "Each dropdown field option must contain " +
          "exactly two String values and the second value must not be empty.")
      }

      return FieldDropdown(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        // Reconstruct options into array of (String, String) tuples
        // eg.[(displayName: "Name 1", value: "Value 1"), (displayName: "Name 2", value: "Value 2")]
        options: options.map({ (displayName: $0[0], value: $0[1]) }))

    case .Image:
      return FieldImage(
        name: (json[PARAMETER_NAME] as? String ?? ""),
        imageURL: (json[PARAMETER_IMAGE_URL] as? String ??
          "https://www.gstatic.com/codesite/ph/images/star_on.gif"),
        size: CGSizeMake(
          CGFloat((json[PARAMETER_WIDTH] as? Int) ?? 15),
          CGFloat((json[PARAMETER_HEIGHT] as? Int) ?? 15)),
        altText: (json[PARAMETER_ALT_TEXT] as? String ?? "*"))

    case .Input:
      return FieldInput(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        text: (json[PARAMETER_TEXT] as? String ?? "default"))

    case .Label:
      return FieldLabel(
        name: (json[PARAMETER_NAME] as? String ?? ""),
        text: (json[PARAMETER_TEXT] as? String ?? ""))

    case .Variable:
      return FieldVariable(
        name: (json[PARAMETER_NAME] as? String ?? "NAME"),
        variable: (json[PARAMETER_VARIABLE] as? String ?? "item"))
    }
  }
}
