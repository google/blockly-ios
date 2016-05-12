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
Abstract class for rendering a `UIView` backed by a `Layout`.
*/
public class LayoutView: UIView {

  // MARK: - Properties

  /// Layout object to render
  public final var layout: Layout? {
    didSet {
      if layout == oldValue {
        return
      }

      if let previousValue = oldValue {
        previousValue.delegate = nil
        // Automatically untrack this view in the ViewManager
        ViewManager.sharedInstance.uncacheViewForLayout(previousValue)
      }

      if let newValue = layout {
        newValue.delegate = self
        // Automatically track this view in the ViewManager
        ViewManager.sharedInstance.cacheView(self, forLayout: newValue)

        refreshView()
      } else {
        prepareForReuse()
      }
    }
  }

  /// Flag indicating if `self.frame.origin` should automatically be kept in sync with
  /// `self.layout.viewFrame.origin`. Defaults to `true`.
  public var updateOriginFromLayout = true

  /// Flag indicating if `self.frame.size` should automatically be kept in sync with
  /// `self.layout.viewFrame.size`. Defaults to `true`.
  public var updateBoundsFromLayout = true

  // MARK: - Public

  /**
  Refreshes the view based on the current state of `self.layout`.

  - Parameter flags: Optionally refresh the view for only a given set of flags. By default, this
  value is set to include all flags (i.e. `LayoutFlag.All`).
  */
  public func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) &&
      layout != nil
    {
      if updateBoundsFromLayout && updateOriginFromLayout {
        self.frame = layout!.viewFrame
      } else if updateBoundsFromLayout {
        self.frame.size = layout!.viewFrame.size
      } else if updateOriginFromLayout {
        self.frame.origin = layout!.viewFrame.origin
      }
    }
  }
}

// MARK: - LayoutDelegate implementation

extension LayoutView: LayoutDelegate {
  public final func layoutDidChange(layout: Layout, withFlags flags: LayoutFlag) {
    refreshView(forFlags: flags)
  }
}

// MARK: - Recyclable implementation

extension LayoutView: Recyclable {
  public func prepareForReuse() {
    // NOTE: It is the responsibility of the superview to remove its subviews and not the other way
    // around. Thus, this method does not handle removing this view from its superview.
    self.layout = nil
  }
}
