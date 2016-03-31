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
Handles the management of recyclable views.
*/
@objc(BKYViewManager)
public class ViewManager: NSObject {

  // MARK: - Static Properties

  /// Shared instance.
  public static let sharedInstance = ViewManager()

  // MARK: - Properties

  /// Object pool for holding reusable views.
  private let _objectPool = ObjectPool()

  /// Dictionary of cached BlockViews
  private var _blockViews = [String: BlockView]()

  /// Dictionary of cached views for FieldLayouts
  private var _fieldViews = [String: FieldView]()

  /// Dictionary that maps `Field` subclasses (using their class' `hash()` value) to their
  /// `FieldView` type
  private var _fieldViewMapping = [Int: Recyclable.Type]()

  public override init() {
    super.init()

    // Register the default views for known fields
    registerViewTypeForFieldType(FieldAngle.self, viewType: FieldAngleView.self)
    registerViewTypeForFieldType(FieldCheckbox.self, viewType: FieldCheckboxView.self)
    registerViewTypeForFieldType(FieldColour.self, viewType: FieldColourView.self)
    registerViewTypeForFieldType(FieldDate.self, viewType: FieldDateView.self)
    registerViewTypeForFieldType(FieldDropdown.self, viewType: FieldDropdownView.self)
    registerViewTypeForFieldType(FieldImage.self, viewType: FieldImageView.self)
    registerViewTypeForFieldType(FieldInput.self, viewType: FieldInputView.self)
    registerViewTypeForFieldType(FieldLabel.self, viewType: FieldLabelView.self)
  }

  // MARK: - Public - Block View

  /**
  Returns the `BlockView` that has been cached for the given layout. If the view could not be found
  in the cache, nil is returned.

  - Parameter layout: The given `BlockLayout`
  - Returns: A `BlockView` with the given layout assigned to it, or nil
  */
  public func cachedBlockViewForLayout(layout: BlockLayout) -> BlockView? {
    // Try to see if the view already exists
    if let cachedView = _blockViews[layout.uuid] {
      return cachedView
    }
    return nil
  }

  /**
  Returns a recycled or new `BlockView` instance assigned to the given layout. This view is stored
  in the internal cache for future lookup.

  - Parameter layout: The given `BlockLayout`
  - Returns: A `BlockView` with the given layout assigned to it
  */
  public func newBlockViewForLayout(layout: BlockLayout) -> BlockView {
    // Get a fresh view and populate it with the layout
    let blockView = viewForType(BlockView.self)
    blockView.layout = layout

    // Cache it for future lookups
    _blockViews[layout.uuid] = blockView

    return blockView
  }

  /**
  If it exists, removes the block view associated with a given block layout.

  - Parameter layout: The given layout
  */
  public func uncacheBlockViewForLayout(layout: BlockLayout) {
    _blockViews[layout.uuid] = nil
  }

  // MARK: - Public - Field View

  /**
  Returns the `LayoutView` that has been cached for the given layout. If the view could not be found
  in the cache, nil is returned.

  - Parameter layout: The given `FieldLayout`
  - Returns: A `LayoutView` with the given layout assigned to it, or nil
  */
  public func cachedFieldViewForLayout(layout: FieldLayout) -> LayoutView? {
    // Try to see if the view already exists
    if let cachedView = _fieldViews[layout.uuid] {
      return cachedView
    }
    return nil
  }

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
  public func newFieldViewForLayout(layout: FieldLayout) throws -> FieldView {
    let fieldType = layout.field.dynamicType
    if let viewType = _fieldViewMapping[fieldType.hash()],
      let layoutView = recyclableViewForType(viewType) as? FieldView
    {
      layoutView.layout = layout
      // Cache it for future lookups
      _fieldViews[layout.uuid] = layoutView
      return layoutView
    } else {
      throw BlocklyError(.ViewNotFound, "Could not retrieve view for \(fieldType)")
    }
  }

  /**
  If it exists, removes the field view associated with a given field layout.

  - Parameter layout: The given layout
  */
  public func uncacheFieldViewForLayout(layout: FieldLayout) {
    _fieldViews[layout.uuid] = nil
  }

  /**
   Registers the type of `FieldView` instances that should be created when requesting a specific
   `Field` type.

   - Parameter fieldType: The `Field.Type` key
   - Parameter viewType: A view type that is a subclass of `FieldView` that conforms to
   `Recyclable`
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
