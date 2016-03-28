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
 Protocol for events that occur on a `Field` instance.
 */
@objc(BKYFieldDelegate)
public protocol FieldDelegate: class {
  /**
   Event that is fired when one of a field's properties has changed.

   - Parameter field: The field that changed.
   */
  func didUpdateField(field: Field)
}

/**
Input field.  Used for editable titles, variables, etc. This is an abstract class that defines the
UI on the block.  Actual instances would be `FieldLabel`, `FieldDropdown`, etc.
*/
@objc(BKYField)
public class Field: NSObject {
  // MARK: - Properties

  /// The name of the field
  public let name: String

  /// The input that owns this field
  public weak var sourceInput: Input!

  /// A delegate for listening to events on this field
  public weak var delegate: FieldDelegate?

  /// Convenience property for accessing `self.delegate` as a FieldLayout
  public var layout: FieldLayout? {
    return self.delegate as? FieldLayout
  }

  // TODO:(#26) Update all fields so that this property is respected.
  /// Flag indicating if this field can be edited
  private var _editable: Bool = true
  public var editable: Bool {
    get {
      return _editable && sourceInput.sourceBlock.editable
    }
    set {
      if _editable != newValue {
        _editable = newValue
        delegate?.didUpdateField(self)
      }
    }
  }

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

  /**
   Sets the native value of this field from a serialized text value.

   - Parameter text: The serialized text value
   - Throws:
   `BlocklyError`: Thrown if the serialized text value could not be converted into the field's
   native value.
   - Note: This method needs to be implemented by a subclass of `Field`. Results are undefined if
   a `Field` subclass does not implement this method.
   */
  public func setValueFromSerializedText(text: String) throws {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  /**
   Converts the native value of this field to a serialized text value.

   - Returns: The serialized text value. If the field cannot be serialized, nil is returned instead.
   - Throws:
   `BlocklyError`: Thrown if the field's native value could not be serialized into a text value.
   - Note: This method needs to be implemented by a subclass of `Field`. Results are undefined if
   a `Field` subclass does not implement this method.
   */
  public func serializedText() throws -> String? {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
    return nil
  }
}
