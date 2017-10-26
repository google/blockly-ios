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
 Factory responsible for returning new `Layout` instances based on a corresponding model object.
 */
@objc(BKYLayoutFactory)
@objcMembers open class LayoutFactory: NSObject {
  // MARK: - Closures

  /// Closure for returning a `BlockLayout` from a given `Block` and `LayoutEngine`.
  public typealias BlockLayoutCreator =
    (_ block: Block, _ engine: LayoutEngine) throws -> BlockLayout
  /// Closure for returning a `BlockGroupLayout` from a given `LayoutEngine`.
  public typealias BlockGroupLayoutCreator = (_ engine: LayoutEngine) throws -> BlockGroupLayout
  /// Closure for returning an `InputLayout` from a given `Input` and `LayoutEngine`, and the
  // `LayoutFactory` that called the closure.
  public typealias InputLayoutCreator =
    (_ input: Input, _ engine: LayoutEngine, _ factory: LayoutFactory) throws -> InputLayout
  /// Closure for returning a `FieldLayout` from a given `Field` and `LayoutEngine`.
  public typealias FieldLayoutCreator =
    (_ field: Field, _ engine: LayoutEngine) throws -> FieldLayout
  /// Closure for returning a `MutatorLayout` from a given `Mutator` and `LayoutEngine`.
  public typealias MutatorLayoutCreator =
    (_ mutator: Mutator, _ engine: LayoutEngine) throws -> MutatorLayout

  // MARK: - Properties

  /// Closure for creating a `BlockLayout`.
  fileprivate var _blockLayoutCreator: BlockLayoutCreator
  /// Closure for creating a `BlockGroupLayout`.
  fileprivate var _blockGroupLayoutCreator: BlockGroupLayoutCreator
  /// Closure for creating an `InputLayout`.
  fileprivate var _inputLayoutCreator: InputLayoutCreator
  /// Dictionary that maps `Field` subclasses types to their `FieldLayoutCreator`
  fileprivate var _fieldLayoutCreators = [ObjectIdentifier: FieldLayoutCreator]()
  /// Dictionary that maps `Mutator` implmentation types to their `MutatorLayoutCreator`
  fileprivate var _mutatorLayoutCreators = [ObjectIdentifier: MutatorLayoutCreator]()

  // MARK: - Initializers

  public override init() {
    // Register required layout creators
    _blockLayoutCreator = { block, engine in
      return DefaultBlockLayout(block: block, engine: engine)
    }
    _blockGroupLayoutCreator = { engine in
      return DefaultBlockGroupLayout(engine: engine)
    }
    _inputLayoutCreator = { input, engine, factory in
      return try DefaultInputLayout(input: input, engine: engine, factory: factory)
    }
    super.init()

    // Register layout creators for default fields
    registerFieldLayoutCreator(forType: FieldAngle.self) { field, engine in
      return FieldAngleLayout(
        fieldAngle: field as! FieldAngle, engine: engine, measurer: FieldAngleView.self)
    }

    registerFieldLayoutCreator(forType: FieldCheckbox.self) { field, engine in
      return FieldCheckboxLayout(
        fieldCheckbox: field as! FieldCheckbox, engine: engine, measurer: FieldCheckboxView.self)
    }

    registerFieldLayoutCreator(forType: FieldColor.self) { field, engine in
      return FieldColorLayout(
        fieldColor: field as! FieldColor, engine: engine, measurer: FieldColorView.self)
    }

    registerFieldLayoutCreator(forType: FieldDate.self) { field, engine in
      return FieldDateLayout(
        fieldDate: field as! FieldDate, engine: engine, measurer: FieldDateView.self)
    }

    registerFieldLayoutCreator(forType: FieldDropdown.self) { field, engine in
      return FieldDropdownLayout(
        fieldDropdown: field as! FieldDropdown, engine: engine, measurer: FieldDropdownView.self)
    }

    registerFieldLayoutCreator(forType: FieldImage.self) { field, engine in
      return FieldImageLayout(
        fieldImage: field as! FieldImage, engine: engine, measurer: FieldImageView.self)
    }

    registerFieldLayoutCreator(forType: FieldInput.self) { field, engine in
      return FieldInputLayout(
        fieldInput: field as! FieldInput, engine: engine, measurer: FieldInputView.self)
    }

    registerFieldLayoutCreator(forType: FieldLabel.self) { field, engine in
      return FieldLabelLayout(
        fieldLabel: field as! FieldLabel, engine: engine, measurer: FieldLabelView.self)
    }

    registerFieldLayoutCreator(forType: FieldNumber.self) { field, engine in
      return FieldNumberLayout(
        fieldNumber: field as! FieldNumber, engine: engine, measurer: FieldNumberView.self)
    }

    registerFieldLayoutCreator(forType: FieldVariable.self) { field, engine in
      return FieldVariableLayout(
        fieldVariable: field as! FieldVariable, engine: engine, measurer: FieldVariableView.self)
    }

    // Register layout creators for mutators

    registerMutatorLayoutCreator(forType: MutatorIfElse.self) { mutator, engine in
      return MutatorIfElseLayout(mutator: mutator as! MutatorIfElse, engine: engine)
    }

    registerMutatorLayoutCreator(forType: MutatorProcedureCaller.self) { mutator, engine in
      return MutatorProcedureCallerLayout(
        mutator: mutator as! MutatorProcedureCaller, engine: engine)
    }

    registerMutatorLayoutCreator(forType: MutatorProcedureDefinition.self) { mutator, engine in
      return MutatorProcedureDefinitionLayout(
        mutator: mutator as! MutatorProcedureDefinition, engine: engine)
    }

    registerMutatorLayoutCreator(forType: MutatorProcedureIfReturn.self) { mutator, engine in
      return MutatorProcedureIfReturnLayout(
        mutator: mutator as! MutatorProcedureIfReturn, engine: engine)
    }
  }

  // MARK: - Layout Makers

  /**
   Builds and returns a `BlockLayout` for a given block and layout engine.

   - note: See `registerBlockLayoutCreator(_)` for more information.
   - parameter block: The given `Block`.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `BlockLayout` instance.
   - throws:
   `BlocklyError`: Thrown if a new `BlockLayout` could not be created for `block`.
   */
  open func makeBlockLayout(block: Block, engine: LayoutEngine) throws -> BlockLayout {
    return try _blockLayoutCreator(block, engine)
  }

  /**
   Builds and returns a `BlockGroupLayout` for a given layout engine.

   - note: See `registerBlockGroupLayoutCreator(_)` for more information.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `BlockGroupLayout` instance.
   - throws:
   `BlocklyError`: Thrown if a new `BlockGroupLayout` could not be created.
   */
  open func makeBlockGroupLayout(engine: LayoutEngine) throws -> BlockGroupLayout {
    return try _blockGroupLayoutCreator(engine)
  }

  /**
   Builds and returns an `InputLayout` for a given input and layout engine.

   - note: See `registerInputLayoutCreator(_)` for more information.
   - parameter input: The given `Input`.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `InputLayout` instance.
   - throws:
   `BlocklyError`: Thrown if a new `InputLayout` could not be created for `input`.
   */
   open func makeInputLayout(input: Input, engine: LayoutEngine) throws -> InputLayout {
    return try _inputLayoutCreator(input, engine, self)
   }

  /**
   Builds and returns a `FieldLayout` for a given field and layout engine.

   - note: See `registerFieldLayoutCreator(forType:layoutCreator:)` for more information.
   - parameter field: The given `Field`.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `FieldLayout` instance.
   - throws:
   `BlocklyError`: Thrown if no suitable `FieldLayout` could be found for the `field`.
   */
  open func makeFieldLayout(field: Field, engine: LayoutEngine) throws -> FieldLayout {
    let fieldTypeObjectID = ObjectIdentifier(type(of: field))
    if let closure = _fieldLayoutCreators[fieldTypeObjectID] {
      return try closure(field, engine)
    }

    throw BlocklyError(.layoutNotFound, "Could not find `FieldLayout` for \(type(of: field))")
  }

  /**
   Builds and returns a `MutatorLayout` for a given mutator and layout engine.

   - note: See `registerMutatorLayoutCreator(forType:layoutCreator:)` for more information.
   - parameter mutator: The given `Mutator`.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `MutatorLayout` instance.
   - throws:
   `BlocklyError`: Thrown if no suitable `MutatorLayout` could be found for the `mutator`.
   */
  open func makeMutatorLayout(mutator: Mutator, engine: LayoutEngine) throws -> MutatorLayout {
    let mutatorTypeObjectID = ObjectIdentifier(type(of: mutator))
    if let closure = _mutatorLayoutCreators[mutatorTypeObjectID] {
      return try closure(mutator, engine)
    }

    throw BlocklyError(.layoutNotFound, "Could not find `MutatorLayout` for \(type(of: mutator))")
  }

  // MARK: - Registering Layout Creators

  /**
   Registers the `BlockLayoutCreator` to use when a new `BlockLayout` instance is requested via
   `makeBlockLayout(block:engine:)`.

   - parameter layoutCreator: The `BlockLayoutCreator` to register.
   */
  open func registerBlockLayoutCreator(_ layoutCreator: @escaping BlockLayoutCreator) {
    _blockLayoutCreator = layoutCreator
  }

  /**
   Registers the `BlockGroupLayoutCreator` to use when a new `BlockGroupLayout` instance is
   requested via `makeBlockGroupLayout(engine:)`.

   - parameter layoutCreator: The `BlockGroupLayoutCreator` to register.
   */
  open func registerBlockGroupLayoutCreator(_ layoutCreator: @escaping BlockGroupLayoutCreator) {
    _blockGroupLayoutCreator = layoutCreator
  }

  /**
   Registers the `InputLayoutCreator` to use when a new `InputLayout` instance is requested via
   `makeInputLayout(input:engine:)`.

   - parameter layoutCreator: The `InputLayoutCreator` to register.
   */
  open func registerInputLayoutCreator(_ layoutCreator: @escaping InputLayoutCreator) {
    _inputLayoutCreator = layoutCreator
  }

  /**
   Registers the `FieldLayoutCreator` to use for a given field type, when a new `FieldLayout`
   instance is requested via `makeFieldLayout(field:engine:)`.

   - parameter fieldType: The `Field.Type` that the creator should be mapped to.
   - parameter layoutCreator: The `FieldLayoutCreator` to register for `fieldType`.
   */
  open func registerFieldLayoutCreator(
    forType fieldType: Field.Type, layoutCreator: @escaping FieldLayoutCreator) {
    _fieldLayoutCreators[ObjectIdentifier(fieldType)] = layoutCreator
  }

  /**
   Registers the `MutatorLayoutCreator` to use for a given mutator type, when a new `MutatorLayout`
   instance is requested via `makeMutatorLayout(mutator:engine:)`.

   - parameter mutatorType: The `Mutator.Type` that the creator should be mapped to.
   - parameter layoutCreator: The `MutatorLayoutCreator` to register for `mutatorType`.
   */
  open func registerMutatorLayoutCreator(
    forType mutatorType: Mutator.Type, layoutCreator: @escaping MutatorLayoutCreator) {
    _mutatorLayoutCreators[ObjectIdentifier(mutatorType)] = layoutCreator
  }
}
