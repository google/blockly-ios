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
open class DefaultLayoutFactory: NSObject {
  // MARK: - Closures

  /// Closure for returning a `FieldLayout` from a given `Field` and `LayoutEngine`
  public typealias FieldLayoutCreator =
    (_ field: Field, _ engine: LayoutEngine) throws -> FieldLayout

  // MARK: - Properties

  /// Dictionary that maps `Field` subclasses (using their class' `hash()` value) to their
  /// `FieldLayoutCreator`
  fileprivate var _fieldLayoutCreators = [Int: FieldLayoutCreator]()

  // MARK: - Initializers

  /// Initializes the default layout factory.
  public override init() {
    super.init()

    // Register layout creators for default fields
    registerLayoutCreator(forFieldType: FieldAngle.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldAngleLayout(
        fieldAngle: field as! FieldAngle, engine: engine, measurer: FieldAngleView.self)
    }

    registerLayoutCreator(forFieldType: FieldCheckbox.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldCheckboxLayout(
        fieldCheckbox: field as! FieldCheckbox, engine: engine, measurer: FieldCheckboxView.self)
    }

    registerLayoutCreator(forFieldType: FieldColor.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldColorLayout(
        fieldColor: field as! FieldColor, engine: engine, measurer: FieldColorView.self)
    }

    registerLayoutCreator(forFieldType: FieldDate.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldDateLayout(
        fieldDate: field as! FieldDate, engine: engine, measurer: FieldDateView.self)
    }

    registerLayoutCreator(forFieldType: FieldDropdown.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldDropdownLayout(
        fieldDropdown: field as! FieldDropdown, engine: engine, measurer: FieldDropdownView.self)
    }

    registerLayoutCreator(forFieldType: FieldImage.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldImageLayout(
        fieldImage: field as! FieldImage, engine: engine, measurer: FieldImageView.self)
    }

    registerLayoutCreator(forFieldType: FieldInput.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldInputLayout(
        fieldInput: field as! FieldInput, engine: engine, measurer: FieldInputView.self)
    }

    registerLayoutCreator(forFieldType: FieldLabel.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLabelLayout(
        fieldLabel: field as! FieldLabel, engine: engine, measurer: FieldLabelView.self)
    }

    registerLayoutCreator(forFieldType: FieldNumber.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldNumberLayout(
        fieldNumber: field as! FieldNumber, engine: engine, measurer: FieldNumberView.self)
    }

    registerLayoutCreator(forFieldType: FieldVariable.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldVariableLayout(
        fieldVariable: field as! FieldVariable, engine: engine, measurer: FieldVariableView.self)
    }
  }

  // MARK: - Open

  /**
   Registers the `FieldLayoutCreator` to use for a given field type, when a new `FieldLayout`
   instance is requested via `layoutForField(:, engine:)`.

   - parameter fieldType: The `Field.Type` that the creator should be mapped to.
   - parameter layoutCreator: The `FieldLayoutCreator` that will be used for `fieldType`.
   */
  open func registerLayoutCreator(forFieldType fieldType: Field.Type,
    layoutCreator: @escaping FieldLayoutCreator)
  {
    _fieldLayoutCreators[fieldType.hash()] = layoutCreator
  }

  /**
   Unregisters the `FieldLayoutCreator` for a given field type.

   - parameter fieldType: The `Field.Type`
   */
  open func unregisterLayoutCreator(forFieldType fieldType: Field.Type) {
    _fieldLayoutCreators.removeValue(forKey: fieldType.hash())
  }
}

// MARK: - LayoutFactory Implementation

extension DefaultLayoutFactory: LayoutFactory {
  // MARK: - Public

  open func makeBlockLayout(block: Block, engine: LayoutEngine) throws -> BlockLayout {
    return DefaultBlockLayout(block: block, engine: engine)
  }

  open func makeBlockGroupLayout(engine: LayoutEngine) throws -> BlockGroupLayout {
    return DefaultBlockGroupLayout(engine: engine)
  }

  open func makeInputLayout(input: Input, engine: LayoutEngine) throws -> InputLayout {
    return try DefaultInputLayout(input: input, engine: engine, factory: self)
  }

  open func makeFieldLayout(field: Field, engine: LayoutEngine) throws -> FieldLayout {
    let fieldTypeHash = type(of: field).hash()
    if let closure = _fieldLayoutCreators[fieldTypeHash] {
      return try closure(field, engine)
    }

    throw BlocklyError(.layoutNotFound, "Could not find layout for \(type(of: field))")
  }
}
