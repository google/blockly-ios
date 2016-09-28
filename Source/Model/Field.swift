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
  func didUpdateField(_ field: Field)
}

/**
Input field.  Used for editable titles, variables, etc. This is an abstract class that defines the
UI on the block.  Actual instances would be `FieldLabel`, `FieldDropdown`, etc.
*/
@objc(BKYField)
open class Field: NSObject {
  // MARK: - Properties

  /// The name of the field
  public let name: String

  /// The input that owns this field
  public weak var sourceInput: Input?

  /// A delegate for listening to events on this field
  public weak var delegate: FieldDelegate?

  /// Convenience property for accessing `self.delegate` as a FieldLayout
  public var layout: FieldLayout? {
    return self.delegate as? FieldLayout
  }

  /// Flag indicating if this field can be edited
  public var editable: Bool = true {
    didSet {
      if editable == oldValue {
        return
      }
      delegate?.didUpdateField(self)
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
  open func copyField() -> Field {
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
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
  open func setValueFromSerializedText(_ text: String) throws {
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
  }

  /**
   Converts the native value of this field to a serialized text value.

   - Returns: The serialized text value. If the field cannot be serialized, nil is returned instead.
   - Throws:
   `BlocklyError`: Thrown if the field's native value could not be serialized into a text value.
   - Note: This method needs to be implemented by a subclass of `Field`. Results are undefined if
   a `Field` subclass does not implement this method.
   */
  open func serializedText() throws -> String? {
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
    return nil
  }

  // MARK: - Public

  /**
   A convenience method that should be called inside the `didSet { ... }` block of instance
   properties from `Field` subclasses.

   If `self.editable == true` and `editableProperty != oldValue`, this method will automatically
   call `delegate?.didUpdateField(self)`.

   If `self.editable == true` and `editableProperty == oldValue`, nothing happens.

   If `self.editable == false`, this method automatically reverts `editableProperty` back to
   `oldValue`.

   Usage:
   ```
   var someInteger: Int {
     didSet { didSetEditableProperty(&someInteger, oldValue) }
   }
   ```

   - Parameter editableProperty: The instance property that had been set
   - Parameter oldValue: The old value of the instance property
   - Returns: `true` if `editableProperty` is now different than `oldValue`, `false` otherwise.
   */
  @discardableResult
  open func didSetEditableProperty<T: Equatable>(_ editableProperty: inout T, _ oldValue: T)
    -> Bool
  {
    if !self.editable {
      editableProperty = oldValue
    }
    if editableProperty == oldValue {
      return false
    }
    delegate?.didUpdateField(self)
    return true
  }

  /**
   A convenience method that should be called inside the `didSet { ... }` block of instance
   properties from `Field` subclasses.

   If `self.editable == true` and `editableProperty != oldValue`, this method will automatically
   call `delegate?.didUpdateField(self)`.

   If `self.editable == true` and `editableProperty == oldValue`, nothing happens.

   If `self.editable == false`, this method automatically reverts `editableProperty` back to
   `oldValue`.

   Usage:
   ```
   var someInteger: Int {
     didSet { didSetEditableProperty(&someInteger, oldValue) }
   }
   ```

   - Parameter editableProperty: The instance property that had been set
   - Parameter oldValue: The old value of the instance property
   - Returns: `true` if `editableProperty` is now different than `oldValue`, `false` otherwise.
   */
  @discardableResult
  open func didSetEditableProperty<T: Equatable>(_ editableProperty: inout T?, _ oldValue: T?)
    -> Bool
  {
    if !self.editable {
      editableProperty = oldValue
    }
    if editableProperty == oldValue {
      return false
    }
    delegate?.didUpdateField(self)
    return true
  }
}
