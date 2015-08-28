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

extension Input {
  // MARK: - Internal

  /**
  Creates a new `Input` from a JSON dictionary.

  - Parameter json: JSON dictionary
  - Parameter sourceBlock: The block that will be associated with the input
  - Returns: An `Input` instance based on the JSON dictionary, or `nil` if there wasn't sufficient
  data in the dictionary.
  */
  internal static func inputFromJSON(json: [String: AnyObject], sourceBlock: Block) -> Input? {
    guard let type = Input.InputType(string: ((json["type"] as? String) ?? "")) else {
      return nil
    }

    let name = (json["name"] as? String) ?? "NAME"
    let input = Input(type: type, name: name, sourceBlock: sourceBlock)

    // Set alignment
    if let alignmentString = json["align"] as? String,
      alignment = Input.Alignment(string: alignmentString) {
        input.alignment = alignment
    }

    // Set input connection's typeChecks
    if let connection = input.connection {
      switch (json["check"]) {
      case let array as [String]:
        connection.typeChecks = array
      case let string as String:
        connection.typeChecks = [string]
      default:
        connection.typeChecks = nil
      }
    }

    return input
  }
}
