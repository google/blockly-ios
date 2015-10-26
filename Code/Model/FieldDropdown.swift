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
public class FieldDropdown: Field {
  // MARK: - Properties

  /// Drop-down options. First value is the display name, second value is the option value.
  public var options: [(displayName: String, value: String)]

  // MARK: - Initializers

  public init(name: String, options: [(displayName: String, value: String)], workspace: Workspace) {
    self.options = options

    super.init(name: name, workspace: workspace)
  }

  public convenience init(
    name: String, displayNames: [String], values: [String], workspace: Workspace) throws {
      if (displayNames.count != values.count) {
        throw BlocklyError(.InvalidBlockDefinition,
          "displayNames.count (\(displayNames.count)) doesn't match values.count (\(values.count))")
      }
      let options = Array(
        zip(displayNames, values) // Creates tuples of (displayNames[i], values[i])
        .map { (displayName: $0.0, value: $0.1) }) // Re-map each tuple as (displayName:, value:)
      self.init(name: name, options: options, workspace: workspace)
  }

  // MARK: - Super

  public override func copyToWorkspace(workspace: Workspace) -> Field {
    return FieldDropdown(name: name, options: options, workspace: workspace)
  }
}
