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

/**
 Handles the creation of recyclable views.
 
 // TODO:(#124) Re-factor this class so it simply registers view types to layout types. There is no
 need to differentiate for BlockView/FieldView/etc.
 */
@objc(BKYViewFactory)
public class ViewFactory: NSObject {

  // MARK: - Static Properties

  /// Shared instance that is used throughout the app
  public static var sharedInstance = ViewFactory()

  // MARK: - Properties

  /// Object pool for holding reusable views.
  private let _objectPool = ObjectPool()

  /// Dictionary that maps `BlockLayout` subclasses (using their class' `hash()` value) to their
  /// `BlockView` type
  private var _blockViewMapping = [Int: Recyclable.Type]()

  /// Dictionary that maps `Field` subclasses (using their class' `hash()` value) to their
  /// `FieldView` type
  private var _fieldViewMapping = [Int: Recyclable.Type]()

  public override init() {
    super.init()

    // Register the default views for known block views
    registerViewTypeForBlockLayoutType(DefaultBlockLayout.self, viewType: DefaultBlockView.self)

    // Register the default views for known fields
    registerViewTypeForFieldType(FieldAngle.self, viewType: FieldAngleView.self)
    registerViewTypeForFieldType(FieldCheckbox.self, viewType: FieldCheckboxView.self)
    registerViewTypeForFieldType(FieldColor.self, viewType: FieldColorView.self)
    registerViewTypeForFieldType(FieldDate.self, viewType: FieldDateView.self)
    registerViewTypeForFieldType(FieldDropdown.self, viewType: FieldDropdownView.self)
    registerViewTypeForFieldType(FieldImage.self, viewType: FieldImageView.self)
    registerViewTypeForFieldType(FieldInput.self, viewType: FieldInputView.self)
    registerViewTypeForFieldType(FieldLabel.self, viewType: FieldLabelView.self)
    registerViewTypeForFieldType(FieldNumber.self, viewType: FieldNumberView.self)
    registerViewTypeForFieldType(FieldVariable.self, viewType: FieldVariableView.self)
  }

  // MARK: - Public - Block View

  public func viewForBlockGroupLayout(blockGroupLayout: BlockGroupLayout) throws -> BlockGroupView {
    // TODO:(#124) Implement this properly so it uses a default registry and uses recycled view
    // (like the other methods in this class)
    let blockGroupView = viewForType(BlockGroupView.self)
    blockGroupView.layout = blockGroupLayout
    return blockGroupView
  }

  public func viewForInputLayout(inputLayout: InputLayout) throws -> InputView {
    // TODO:(#124) Implement this properly so it uses a default registry and uses recycled view
    // (like the other methods in this class)
    let inputView = viewForType(InputView.self)
    inputView.layout = inputLayout
    return inputView
  }

  /**
   Returns a recycled or new `BlockView` instance assigned to the given layout. This view is stored
   in the internal cache for future lookup.

   - Parameter layout: The given `BlockLayout`
   - Returns: A `BlockView` with the given layout assigned to it
   - Throws:
   `BlocklyError`: Thrown if no `BlockView` could be retrieved for the given layout.
   */
  public func blockViewForLayout(layout: BlockLayout) throws -> BlockView {
    // Get a fresh view and populate it with the layout
    let blockLayoutType = layout.dynamicType
    if let viewType = _blockViewMapping[blockLayoutType.hash()],
      let blockView = recyclableViewForType(viewType) as? BlockView
    {
      blockView.layout = layout
      return blockView
    } else {
      throw BlocklyError(.ViewNotFound, "Could not retrieve view for \(blockLayoutType)")
    }
  }

  /**
   Registers the type of `BlockView` instances that should be created when requesting a specific
   `BlockLayout` type.

   - Parameter blockLayoutType: The `BlockLayout.Type` key
   - Parameter viewType: A view type that is a subclass of `FieldView` that conforms to
   `Recyclable`
   */
  public func registerViewTypeForBlockLayoutType
    <LayoutView where LayoutView: BlockView, LayoutView: Recyclable>
    (blockLayoutType: BlockLayout.Type, viewType: LayoutView.Type)
  {
    _blockViewMapping[blockLayoutType.hash()] = viewType
  }

  /**
   Unregisters the type of `FieldView` instance that should be created when requesting a specific
   `Field` type.

   - Parameter fieldType: The `Field.Type` key
   */
  public func unregisterViewTypeForBlockLayoutType(blockLayoutType: BlockLayout.Type) {
    _blockViewMapping[blockLayoutType.hash()] = nil
  }

  // MARK: - Public - Field View

  /**
   Returns a recycled `FieldView` instance assigned to the given layout's `field`.
   If one isn't found, a new one is created based on the `FieldView` type that was registered via
   `registerFieldViewType(:, fieldType:)`. This view is then stored in the internal cache for
   future lookup.

   - Parameter layout: The given `FieldLayout`
   - Returns: A `FieldView` with the given layout assigned to it
   - Throws:
   `BlocklyError`: Thrown if no `FieldView` could be retrieved for the given layout.
   */
  public func fieldViewForLayout(layout: FieldLayout) throws -> FieldView {
    let fieldType = layout.field.dynamicType
    if let viewType = _fieldViewMapping[fieldType.hash()],
      let fieldView = recyclableViewForType(viewType) as? FieldView
    {
      fieldView.layout = layout
      return fieldView
    } else {
      throw BlocklyError(.ViewNotFound, "Could not retrieve view for \(fieldType)")
    }
  }

  /**
   Registers the type of `FieldView` instances that should be created when requesting a specific
   `Field` type.

   - Parameter fieldType: The `Field.Type` key
   - Parameter viewType: A view type that is a subclass of `FieldView` that conforms to
   `Recyclable`

   TODO:(#115) Switch to registering FieldLayout.Type instead of Field.Type
   */
  public func registerViewTypeForFieldType
    <LayoutView where LayoutView: FieldView, LayoutView: Recyclable>
    (fieldType: Field.Type, viewType: LayoutView.Type)
  {
    _fieldViewMapping[fieldType.hash()] = viewType
  }

  /**
   Unregisters the type of `FieldView` instance that should be created when requesting a specific
   `Field` type.

   - Parameter fieldType: The `Field.Type` key
   */
  public func unregisterViewTypeForFieldType(fieldType: Field.Type) {
    _fieldViewMapping[fieldType.hash()] = nil
  }

  // MARK: - Public - Recyclable Views

  /**
  If a recycled view is available for re-use, that view is returned.
  If not, a new view of the given type is instantiated.

  - Parameter type: The type of UIView<Recyclable> object to retrieve.
  - Note: Views obtained through this method should be recycled through `recycleView(:)`.
  - Returns: A view of the given type.
  */
  public func viewForType<RecyclableView where RecyclableView: UIView, RecyclableView: Recyclable>
    (type: RecyclableView.Type) -> RecyclableView {
      return _objectPool.objectForType(type)
  }

  /**
   If a recycled view is available for re-use, that view is returned.
   If not, a new view of the given type is instantiated.

   - Parameter type: The type of Recyclable object to retrieve.
   - Note: Views obtained through this method should be recycled through `recycleView(:)`.
   - Warning: This method should only be called by Objective-C code. Swift code should use
   `viewForType(:)` instead.
   - Returns: A view of the given type, if it is a UIView. Otherwise, nil is returned.
   */
  public func recyclableViewForType(type: Recyclable.Type) -> UIView? {
    return _objectPool.recyclableObjectForType(type) as? UIView
  }

  /**
   If the view conforms to the protocol `Recyclable`, calls `recycle()` on the view and stores it
   for re-use later. Otherwise, nothing happens.

   - Parameter view: The view to recycle.
   - Note: Views recycled through this method should be re-obtained through `viewForType(:)`
   or `recyclableViewForType`.
   */
  public func recycleView(view: UIView) {
    if let recyclableView = view as? Recyclable {
      _objectPool.recycleObject(recyclableView)
    } else {
      bky_print(
        "Cannot recycle view [\(view.dynamicType)] that does not conform to protocol [Recyclable]")
    }
  }
}
