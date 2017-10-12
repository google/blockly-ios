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

 This class is designed as a singleton instance, accessible via `ViewManager.shared`.
 */
@objc(BKYViewManager)
@objcMembers public final class ViewManager: NSObject {
  // MARK: - Static Properties

  /// Shared instance.
  public static let shared = ViewManager()

  // MARK: - Initializers

  /**
   A singleton instance for this class is accessible via `ViewManager.shared.`
   */
  private override init() {
  }

  // MARK: - Properties

  /// Dictionary that indexes weak `LayoutView` references based on their `layout.uuid`
  public private(set) var views: NSMapTable<NSString, LayoutView> = NSMapTable.strongToWeakObjects()

  // MARK: - Public

  /**
   Caches a `LayoutView` instance to a specific `Layout`.

   - parameter layoutView: The `LayoutView` to cache
   - parameter layout: The `Layout` associated with the view
   */
  public func cacheView(_ layoutView: LayoutView, forLayout layout: Layout) {
    views.setObject(layoutView, forKey: layout.uuid as NSString?)
  }

  /**
   Uncaches the `LayoutView` associated with a given block layout.

   - parameter layout: The given layout
   */
  public func uncacheView(forLayout layout: Layout) {
    views.removeObject(forKey: layout.uuid as NSString?)
  }

  /**
   Returns the `BlockView` that has been cached for a given `BlockLayout`. If the view could not
   be found in the cache, `nil` is returned.

   - parameter layout: The `BlockLayout` to look for
   - returns: A `BlockView` with the given layout assigned to it, or `nil` if no view could be
   found.
   */
  public func findBlockView(forLayout layout: BlockLayout) -> BlockView? {
    return (findView(forLayout: layout) as? BlockView) ?? nil
  }

  /**
   Returns the `FieldView` that has been cached for a given `FieldLayout`. If the view could not
   be found in the cache, `nil` is returned.

   - parameter layout: The `FieldLayout` to look for
   - returns: A `FieldView` with the given layout assigned to it, or `nil` if no view could be
   found.
   */
  public func findFieldView(forLayout layout: FieldLayout) -> FieldView? {
    return (findView(forLayout: layout) as? FieldView) ?? nil
  }

  /**
   Returns the `LayoutView` that has been cached for a given `Layout`. If the view could not
   be found in the cache, `nil` is returned.

   - parameter layout: The `Layout` to look for
   - returns: A `LayoutView` with the given layout assigned to it, or `nil` if no view could be
   found.
   */
  @inline(__always)
  public func findView(forLayout layout: Layout) -> LayoutView? {
    return views.object(forKey: layout.uuid as NSString?)
  }
}
