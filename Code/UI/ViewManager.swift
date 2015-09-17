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

  /// Dictionary of known BlockViews
  private var _blockViews = [String: BlockView]()

  // MARK: - Public

  /**
  Looks in the internal cache for a `BlockView` that has been assigned the given layout.
  If one is found, it is returned.
  If not, a recycled (or new) `BlockView` instance is created. This instance is assigned the given
  layout, stored in the internal cache for future lookup, and returned.

  - Parameter layout: The given `BlockLayout`.
  - Returns: A `BlockView` with the given layout assigned to it.
  */
  public func blockViewForLayout(layout: BlockLayout) -> BlockView {
    // Try to see if the view already exists
    if let cachedView = _blockViews[layout.block.uuid] {
      return cachedView
    }

    // Get a fresh view and populate it with the layout
    let blockView = viewForType(BlockView.self)
    blockView.layout = layout

    // Cache it for future lookups
    _blockViews[layout.block.uuid] = blockView

    return blockView
  }

  /**
  Looks in the internal cache for a `FieldView` that has been assigned the given layout.
  If one is found, it is returned.
  If not, a recycled (or new) `UIView` instance is created. This instance is assigned the given
  layout, stored in the internal cache for future lookup, and returned.

  - Parameter layout: The given `FieldLayout`.
  - Returns: A `UIView` with the given layout assigned to it.
  */
  public func fieldViewForLayout(layout: FieldLayout) -> UIView? {
    // TODO:(vicng) Implement a lookup mechanism based on a layout ID
    // TODO:(vicng) Implement a way for clients to customize the view based on the layout
    if let fieldLabelLayout = layout as? FieldLabelLayout {
      let fieldLabelView = viewForType(FieldLabelView.self)
      fieldLabelView.layout = fieldLabelLayout
      return fieldLabelView
    }
    return nil
  }

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
