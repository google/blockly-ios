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
 Manages the set `LayoutView` instances that have been created.
 */
@objc(BKYViewManager)
public final class ViewManager: NSObject {
  // MARK: - Static Properties

  /// Shared instance.
  public static let sharedInstance = ViewManager()

  // MARK: - Properties

  /// Dictionary mapping instances of `LayoutView` keyed by their `layout.uuid`
  private var _views = [String: LayoutView]()

  // MARK: - Public

  /**
   Caches a `LayoutView` instance to a specific `Layout`.

   - Parameter layoutView: The `LayoutView` to cache
   - Parameter layout: The `Layout` associated with the view
   */
  public func cacheView(_ layoutView: LayoutView, forLayout layout: Layout) {
    _views[layout.uuid] = layoutView
  }

  /**
   Uncaches the `LayoutView` associated with a given block layout.

   - Parameter layout: The given layout
   */
  public func uncacheView(forLayout layout: Layout) {
    _views[layout.uuid] = nil
  }

  /**
   Returns the `BlockView` that has been cached for a given `BlockLayout`. If the view could not
   be found in the cache, nil is returned.

   - Parameter layout: The `BlockLayout` to look for
   - Returns: A `BlockView` with the given layout assigned to it, or nil if no view could be found.
   */
  public func findBlockView(forLayout layout: BlockLayout) -> BlockView? {
    return (_views[layout.uuid] as? BlockView) ?? nil
  }

  /**
   Returns the `FieldView` that has been cached for a given `FieldLayout`. If the view could not
   be found in the cache, nil is returned.

   - Parameter layout: The `FieldLayout` to look for
   - Returns: A `FieldView` with the given layout assigned to it, or nil if no view could be found.
   */
  public func findFieldView(forLayout layout: FieldLayout) -> FieldView? {
    return (_views[layout.uuid] as? FieldView) ?? nil
  }

  /**
   Returns the `LayoutView` that has been cached for a given `Layout`. If the view could not
   be found in the cache, nil is returned.

   - Parameter layout: The `Layout` to look for
   - Returns: A `LayoutView` with the given layout assigned to it, or nil if no view could be found.
   */
  public func findView(forLayout layout: Layout) -> LayoutView? {
    return _views[layout.uuid]
  }
}
