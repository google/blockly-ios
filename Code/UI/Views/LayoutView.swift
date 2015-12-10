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
  public final weak var layout: Layout? {
    didSet {
      if layout != oldValue {
        oldValue?.delegate = nil
        layout?.delegate = self

        if layout != nil {
          refreshView()
        } else {
          prepareForReuse()
        }
      }
    }
  }

  // MARK: - Abstract

  /**
  Refreshes the view based on the current state `self.layout` and a given set of flags.

  - Parameter flags: Only refresh the view for the flags that have been specified.
  */
  public func internalRefreshView(forFlags flags: LayoutFlag) {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  /**
  Prepares this view to be re-used in the future.
  */
  public func internalPrepareForReuse() {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
  Refreshes the view based on the current state of `self.layout`.

  - Parameter flags: Optionally refresh the view for only a given set of flags. By default, this
  value is set to include all flags (i.e. `LayoutFlag.All`).
  */
  public func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All)
  {
    if flags.intersectsWith(Layout.Flag_UpdateViewFrame) {
      updateViewFrameFromLayout()
    }
    if flags.subtract(Layout.Flag_UpdateViewFrame).hasFlagSet() {
      internalRefreshView(forFlags: flags)
    }
  }

  /**
  Updates `self.frame` based on the current state of `self.layout`.
  */
  public func updateViewFrameFromLayout() {
    if layout != nil {
      self.frame = layout!.viewFrame
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
  public final func prepareForReuse() {
    // NOTE: It is the responsibility of the superview to remove its subviews and not the other way
    // around. Thus, this method does not handle removing this view from its superview.

    self.layout = nil

    internalPrepareForReuse()
  }
}
