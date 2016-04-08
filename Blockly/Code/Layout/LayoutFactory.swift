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

// TODO:(#68) Convert LayoutFactory into a protocol
/**
Factory responsible for returning new instances of Layout objects.
*/
@objc(BKYLayoutFactory)
public class LayoutFactory: NSObject {
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
      return FieldLayout(field: field, engine: engine, measurer: FieldAngleView.self)
    }

    registerLayoutCreatorForFieldType(FieldCheckbox.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldCheckboxView.self)
    }

    registerLayoutCreatorForFieldType(FieldColour.self) {
      (field: Field, engine: LayoutEngine) throws -> FieldLayout in
      return FieldLayout(field: field, engine: engine, measurer: FieldColourView.self)
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
  }

  // MARK: - Public

  /**
  Builds and returns a `BlockLayout` for a given block and layout engine.

  - Parameter block: The given `Block`
  - Parameter engine: The `LayoutEngine` to associate with the new layout
  - Returns: A new `BlockLayout` instance or nil, if either `workspace.layout` is nil or no
  suitable
  layout could be found for the block.
  */
  public func layoutForBlock(block: Block, engine: LayoutEngine) -> BlockLayout {
    return DefaultBlockLayout(block: block, engine: engine)
  }

  /**
  Builds and returns a `BlockGroupLayout` for a given layout engine.

  - Parameter engine: The `LayoutEngine` to associate with the new layout.
  - Returns: A new `BlockGroupLayout` instance.
  */
  public func layoutForBlockGroupLayout(engine engine: LayoutEngine) -> BlockGroupLayout {
    return DefaultBlockGroupLayout(engine: engine)
  }

  /**
  Builds and returns an `InputLayout` for a given input and layout engine.

  - Parameter input: The given `Input`
  - Parameter engine: The `LayoutEngine` to associate with the new layout
  - Returns: A new `InputLayout` instance.
  */
  public func layoutForInput(input: Input, engine: LayoutEngine) -> InputLayout {
    return DefaultInputLayout(input: input, engine: engine, factory: self)
  }

  /**
   Builds and returns a `FieldLayout` for a given field and layout engine, using the
   `FieldLayoutCreator` that was registered via
   `registerLayoutCreatorForFieldType(:, layoutCreator:)`.

    - Parameter field: The given `Field`
    - Parameter engine: The `LayoutEngine` to associate with the new layout
    - Returns: A new `FieldLayout` instance.
    - Throws:
    `BlocklyError`: Thrown if no suitable `FieldLayout` could be found for the `field`.
   */
  public func layoutForField(field: Field, engine: LayoutEngine) throws -> FieldLayout {
    let fieldTypeHash = field.dynamicType.hash()
    if let closure = _fieldLayoutCreators[fieldTypeHash] {
      return try closure(field: field, engine: engine)
    }

    throw BlocklyError(.LayoutNotFound, "Could not find layout for \(field.dynamicType)")
  }

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
