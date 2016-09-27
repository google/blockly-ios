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
 */
@objc(BKYViewFactory)
open class ViewFactory: NSObject {

  // MARK: - Properties

  /// Object pool for holding reusable views.
  private let _objectPool = ObjectPool()

  /// Dictionary that maps `Layout` subclasses (using their class' `hash()` value) to their
  /// `LayoutView` type
  private var _viewMapping = [Int: Recyclable.Type]()

  /**
   Initializes the view factory, and registers the default `Layout`/`View` relationships
   */
  public override init() {
    super.init()

    // Register the views for default layouts
    registerLayoutType(DefaultBlockLayout.self, withViewType: DefaultBlockView.self)
    registerLayoutType(DefaultBlockGroupLayout.self, withViewType: BlockGroupView.self)
    registerLayoutType(DefaultInputLayout.self, withViewType: InputView.self)

    // Register the views for known field layouts
    registerLayoutType(FieldAngleLayout.self, withViewType: FieldAngleView.self)
    registerLayoutType(FieldCheckboxLayout.self, withViewType: FieldCheckboxView.self)
    registerLayoutType(FieldColorLayout.self, withViewType: FieldColorView.self)
    registerLayoutType(FieldDateLayout.self, withViewType: FieldDateView.self)
    registerLayoutType(FieldDropdownLayout.self, withViewType: FieldDropdownView.self)
    registerLayoutType(FieldImageLayout.self, withViewType: FieldImageView.self)
    registerLayoutType(FieldInputLayout.self, withViewType: FieldInputView.self)
    registerLayoutType(FieldLabelLayout.self, withViewType: FieldLabelView.self)
    registerLayoutType(FieldNumberLayout.self, withViewType: FieldNumberView.self)
    registerLayoutType(FieldVariableLayout.self, withViewType: FieldVariableView.self)
  }

  // MARK: - Public

  /**
   Returns a recycled or new `LayoutView` instance assigned to the given layout.

   - Parameter layout: The given `Layout`
   - Returns: A `LayoutView` with the given layout assigned to it
   - Throws:
   `BlocklyError`: Thrown if no `LayoutView` could be retrieved for the given layout.
   */
  open func makeView(layout: Layout) throws -> LayoutView {
    // Get a fresh view and populate it with the layout
    let layoutType = type(of: layout)
    if let viewType = _viewMapping[layoutType.hash()],
      let view = recyclableViewForType(viewType) as? LayoutView
    {
      view.layout = layout
      return view
    } else {
      throw BlocklyError(.viewNotFound, "Could not retrieve view for \(layoutType)")
    }
  }

  /**
   Registers the type of `LayoutView` instances that should be created when requesting a specific
   `Layout` type.

   - Parameter layoutType: The `Layout.Type` key
   - Parameter viewType: A view type that is a subclass of `LayoutView` that conforms to
   `Recyclable`
   */
  open func registerLayoutType(_ layoutType: Layout.Type, withViewType viewType: LayoutView.Type) {
    _viewMapping[layoutType.hash()] = viewType
  }

  /**
   If a recycled view is available for re-use, that view is returned.
   If not, a new view of the given type is instantiated.

   - Parameter type: The type of `Recyclable` object to retrieve.
   - Note: Views obtained through this method should be recycled through `recycleView(:)` or
   `recycleViewTree(:)`.
   - Returns: A view of the given type, if it is a `UIView`. Otherwise, nil is returned.
   */
  open func recyclableViewForType(_ type: Recyclable.Type) -> UIView? {
    return _objectPool.recyclableObjectForType(type) as? UIView
  }

  /**
   If the view conforms to the protocol `Recyclable`, calls `recycle()` on the view and stores it
   for re-use later. Otherwise, nothing happens.

   - Parameter view: The view to recycle.
   */
  open func recycleView(_ view: UIView) {
    if let recyclableView = view as? Recyclable {
      _objectPool.recycleObject(recyclableView)
    }
  }

  /**
   For every `UIView` in a view hierarchy rooted by a given `UIView`, recycles those that conform
   to the protocol `Recyclable` and stores them for re-use later.

   - Parameter rootView: The root view to begin the recycling process.
   */
  open func recycleViewTree(_ rootView: UIView) {
    let subviews = rootView.subviews

    // Recycle root view
    recycleView(rootView)

    // Recursively recycle subviews
    for subview in subviews {
      recycleViewTree(subview)
    }
  }
}
