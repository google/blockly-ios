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
  // MARK: - Static Properties

  // JSON parameters
  private static let PARAMETER_ALT_TEXT = "alt"
  private static let PARAMETER_ANGLE = "angle"
  private static let PARAMETER_CHECKED = "checked"
  private static let PARAMETER_COLOR = "colour"
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
  Creates a new `Field` from a JSON dictionary.

  - Parameter json: JSON dictionary
  - Throws:
  `BlocklyError`: Occurs if malformed JSON data was passed in.
  - Returns: A `Field` instance based on the JSON dictionary, or `nil` if there wasn't sufficient
  data in the dictionary.
  */
  internal static func fieldFromJSON(json: [String: AnyObject]) throws -> Field? {
    let type = json[PARAMETER_TYPE] as? String ?? ""
    if let creationHandler = Field.JSONRegistry.sharedInstance[type] {
      return try creationHandler(json: json)
    } else {
      return nil
    }
  }
}

/**
Manages the registration of fields.
*/
extension Field {
  @objc(BKYFieldJSONRegistry)
  public class JSONRegistry: NSObject {
    // MARK: - Static Properties

    /// Shared instance.
    public static let sharedInstance = JSONRegistry()

    // MARK: - Closures

    /// Callback for creating a Field instance from JSON
    public typealias CreationHandler = (json: [String: AnyObject]) throws -> Field

    // MARK: - Properties

    /// Dictionary mapping JSON field types to its creation handler.
    private var _registry = [String: CreationHandler]()
    public subscript(key: String) -> CreationHandler? {
      get { return _registry[key.lowercaseString] }
      set { _registry[key.lowercaseString] = newValue }
    }

    // MARK: - Initializers

    public override init() {
      super.init()

      // Angle
      registerType("field_angle") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldAngle(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          angle: (json[PARAMETER_ANGLE] as? Int ?? 90))
      }

      // Checkbox
      registerType("field_checkbox") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldCheckbox(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          checked: (json[PARAMETER_CHECKED] as? Bool ?? true))
      }

      // Color
      registerType("field_colour") {
        (json: [String: AnyObject]) throws -> Field in
        let color = UIColor.bky_colorFromRGB(json[PARAMETER_COLOR] as? String ?? "")
        return FieldColor(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          color: (color ?? UIColor.redColor()))
      }

      // Date
      registerType("field_date") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldDate(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          stringDate: (json[PARAMETER_DATE] as? String ?? ""))
      }

      // Dropdown
      registerType("field_dropdown") {
        (json: [String: AnyObject]) throws -> Field in
        // Options should be an array of string arrays.
        // eg. [["Name 1", "Value 1"], ["Name 2", "Value 2"]]
        let options = json[PARAMETER_OPTIONS] as? Array<[String]> ?? []

        // Check that all arrays contain exactly two values and that the second value is not empty
        if (options.filter { ($0.count != 2) || ($0[1] == "") }.count > 0) {
          throw BlocklyError(.InvalidBlockDefinition, "Each dropdown field option must contain " +
            "exactly two String values and the second value must not be empty.")
        }

        return FieldDropdown(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          // Reconstruct options into array of (String, String) tuples
          // eg. [(displayName: "Name 1", value: "Value 1"),
          //     (displayName: "Name 2", value: "Value 2")]
          options: options.map({ (displayName: $0[0], value: $0[1]) }),
          selectedIndex: 0)
      }

      // Image
      registerType("field_image") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldImage(
          name: (json[PARAMETER_NAME] as? String ?? ""),
          imageURL: (json[PARAMETER_IMAGE_URL] as? String ??
            "https://www.gstatic.com/codesite/ph/images/star_on.gif"),
          size: CGSizeMake(
            CGFloat((json[PARAMETER_WIDTH] as? Int) ?? 15),
            CGFloat((json[PARAMETER_HEIGHT] as? Int) ?? 15)),
          altText: (json[PARAMETER_ALT_TEXT] as? String ?? "*"))
      }

      // Input
      registerType("field_input") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldInput(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          text: (json[PARAMETER_TEXT] as? String ?? "default"))
      }

      // Label
      registerType("field_label") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldLabel(
          name: (json[PARAMETER_NAME] as? String ?? ""),
          text: (json[PARAMETER_TEXT] as? String ?? ""))
      }

      // Variable
      registerType("field_variable") {
        (json: [String: AnyObject]) throws -> Field in
        return FieldVariable(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          variable: (json[PARAMETER_VARIABLE] as? String ?? "item"))
      }
    }

    // MARK: - Public

    /**
    Registers a JSON creation handler for a given field key.

    - Parameter type: The key for a field type.
    - Parameter creationHandler: The `CreationHandler` to use for this field key.
    */
    public func registerType(type: String, creationHandler: CreationHandler) {
      _registry[type] = creationHandler
    }

    /**
    Unregisters a JSON creation handler for a given field key.

    - Parameter type: The key for a field type.
    */
    public func unregisterType(type: String) {
      _registry[type] = nil
    }
  }
}
