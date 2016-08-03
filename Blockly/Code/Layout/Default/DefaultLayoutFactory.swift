/*
* Copyright 2016 Google Inc. All Rights Reserved.
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

// MARK: - DefaultLayoutFactory Class

/**
 A default implementation of `LayoutFactory`.
 */
@objc(BKYDefaultLayoutFactory)
public class DefaultLayoutFactory: NSObject {
  /// MARK: - Type Aliases

  /// Closure for returning a `FieldLayout` from a given `Field` and `LayoutEngine`
  public typealias FieldLayoutCreator =
    (field: Field, engine: LayoutEngine) throws -> FieldLayout

  // MARK: - Properties

  /// Dictionary that maps `Field` subclasses (using their class' `hash()` value) to their
  /// `FieldLayoutCreator`
  private var _fieldLayoutCreators = [Int: FieldLayoutCreator]()

  // MARK: - Initializers

  public override init() {
    super.init()

    // Register layout creators for default fields
    registerLayoutCreatorForFieldType(FieldAngle.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldAngleLayout(
        fieldAngle: field as! FieldAngle, engine: engine, measurer: FieldAngleView.self)
    }

    registerLayoutCreatorForFieldType(FieldCheckbox.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldCheckboxLayout(
        fieldCheckbox: field as! FieldCheckbox, engine: engine, measurer: FieldCheckboxView.self)
    }

    registerLayoutCreatorForFieldType(FieldColor.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldColorLayout(
        fieldColor: field as! FieldColor, engine: engine, measurer: FieldColorView.self)
    }

    registerLayoutCreatorForFieldType(FieldDate.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldDateView.self)
    }

    registerLayoutCreatorForFieldType(FieldDropdown.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldDropdownView.self)
    }

    registerLayoutCreatorForFieldType(FieldImage.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldImageView.self)
    }

    registerLayoutCreatorForFieldType(FieldInput.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldInputView.self)
    }

    registerLayoutCreatorForFieldType(FieldLabel.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldLabelView.self)
    }

    registerLayoutCreatorForFieldType(FieldNumber.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldNumberLayout(
        fieldNumber: field as! FieldNumber, engine: engine, measurer: FieldNumberView.self)
    }

    registerLayoutCreatorForFieldType(FieldVariable.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldVariableView.self)
    }
  }

  // MARK: - Public

  /**
   Registers the `FieldLayoutCreator` to use for a given field type, when a new `FieldLayout`
   instance is requested via `layoutForField(:, engine:)`.

   - Parameter fieldType: The `Field.Type` that the creator should be mapped to.
   - Parameter layoutCreator: The `FieldLayoutCreator` that will be used for `fieldType`.
   */
  public func registerLayoutCreatorForFieldType(fieldType: Field.Type,
    layoutCreator: FieldLayoutCreator)
  {
    _fieldLayoutCreators[fieldType.hash()] = layoutCreator
  }

  /**
   Unregisters the `FieldLayoutCreator` for a given field type.

   - Parameter fieldType: The `Field.Type`
   */
  public func unregisterLayoutCreatorForFieldType(fieldType: Field.Type) {
    _fieldLayoutCreators.removeValueForKey(fieldType.hash())
  }
}

// MARK: - LayoutFactory Implementation

extension DefaultLayoutFactory: LayoutFactory {
  // MARK: - Public

  public func layoutForBlock(block: Block, engine: LayoutEngine) throws -> BlockLayout {
    return DefaultBlockLayout(block: block, engine: engine)
  }

  public func layoutForBlockGroupLayout(engine engine: LayoutEngine) throws -> BlockGroupLayout {
    return DefaultBlockGroupLayout(engine: engine)
  }

  public func layoutForInput(input: Input, engine: LayoutEngine) throws -> InputLayout {
    return try DefaultInputLayout(input: input, engine: engine, factory: self)
  }

  public func layoutForField(field: Field, engine: LayoutEngine) throws -> FieldLayout {
    let fieldTypeHash = field.dynamicType.hash()
    if let closure = _fieldLayoutCreators[fieldTypeHash] {
      return try closure(field: field, engine: engine)
    }

    throw BlocklyError(.LayoutNotFound, "Could not find layout for \(field.dynamicType)")
  }
}
