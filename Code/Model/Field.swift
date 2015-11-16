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
Input field.  Used for editable titles, variables, etc. This is an abstract class that defines the
UI on the block.  Actual instances would be `FieldLabel`, `FieldDropdown`, etc.
*/
@objc(BKYField)
public class Field: NSObject {
  // MARK: - Properties

  public let name: String

  // TODO(vicng): Consider replacing the layout reference with a delegate or listener
  /// The layout used for rendering this field
  public var layout: FieldLayout?

  // MARK: - Initializers

  internal init(name: String) {
    self.name = name
    super.init()
  }

  // MARK: - Abstract

  /**
  Returns a copy of this field.

  - Returns: A copy of this field.
  - Note: This method needs to be implemented by a subclass of `Field`. Results are undefined if
  a `Field` subclass does not implement this method.
  */
  public func copyField() -> Field {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
    return Field(name: name) // This shouldn't happen.
  }
}
