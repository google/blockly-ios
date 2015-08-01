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
  // MARK: - Internal

  /**
  Creates a new |Field| from a JSON dictionary.

  - Parameter json: JSON dictionary
  - Returns: A |Field| instance based on the JSON dictionary, or |nil| if there wasn't sufficient
  data in the dictionary.
  */
  public static func fieldFromJSON(json: [String: AnyObject]) -> Field? {
    guard let type = Field.FieldType(string: (json["type"] as? String ?? "")) else {
      return nil
    }

    switch (type) {
    case .Label:
      // TODO:(vicng) Implement
      break;
    case .Input:
      // TODO:(vicng) Implement
      break;
    case .Angle:
      // TODO:(vicng) Implement
      break;
    case .Checkbox:
      // TODO:(vicng) Implement
      break;
    case .Colour:
      // TODO:(vicng) Implement
      break;
    case .Date:
      // TODO:(vicng) Implement
      break;
    case .Variable:
      // TODO:(vicng) Implement
      break;
    case .Dropdown:
      // TODO:(vicng) Implement
      break;
    case .Image:
      // TODO:(vicng) Implement
      break;
    }

    return nil
  }
}
