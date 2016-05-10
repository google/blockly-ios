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

/**
An input field for selecting options from a dropdown menu.
*/
@objc(BKYFieldDropdown)
public final class FieldDropdown: Field {
  public typealias Option = (displayName: String, value: String)

  // MARK: - Properties

  /// Drop-down options. First value is the display name, second value is the option value.
  public var options: [Option] {
    didSet {
      if !self.editable {
        self.options = oldValue
      } else {
        delegate?.didUpdateField(self)
      }
    }
  }

  /// The currently selected index
  public var selectedIndex: Int {
    didSet { didSetEditableProperty(&selectedIndex, oldValue) }
  }

  /// The option tuple of the currently selected index
  public var selectedOption: Option? {
    return 0 <= selectedIndex && selectedIndex < options.count ? options[selectedIndex] : nil
  }

  // MARK: - Initializers

  public init(name: String, options: [(displayName: String, value: String)], selectedIndex: Int) {
    self.options = options
    self.selectedIndex = selectedIndex

    super.init(name: name)
  }

  public convenience init(
    name: String, displayNames: [String], values: [String], selectedIndex: Int) throws {
      if (displayNames.count != values.count) {
        throw BlocklyError(.InvalidBlockDefinition,
          "displayNames.count (\(displayNames.count)) doesn't match values.count (\(values.count))")
      }
      let options = Array(
        zip(displayNames, values) // Creates tuples of (displayNames[i], values[i])
        .map { (displayName: $0.0, value: $0.1) }) // Re-map each tuple as (displayName:, value:)
      self.init(name: name, options: options, selectedIndex: selectedIndex)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldDropdown(name: name, options: options, selectedIndex: selectedIndex)
  }

  public override func setValueFromSerializedText(text: String) throws {
    // Update the selection index to the first available option that has the given value. If
    // there are no options the index will be set to -1. If the value given is empty or does
    // not exist the index will be set to 0.
    if self.options.count == 0 {
      self.selectedIndex = -1
    } else if text == "" {
      self.selectedIndex = 0
    } else {
      var index = 0
      for i in 0 ..< self.options.count {
        if self.options[i].value == text {
          index = i
          break
        }
      }
      self.selectedIndex = index
    }
  }

  public override func serializedText() throws -> String? {
    return self.selectedOption?.value ?? ""
  }
}
