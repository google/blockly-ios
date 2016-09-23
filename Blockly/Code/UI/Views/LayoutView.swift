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
@objc(BKYLayoutView)
open class LayoutView: UIView {

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
        ViewManager.sharedInstance.uncacheView(forLayout: previousValue)
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

  // MARK: - Public

  /**
  Refreshes the view based on the current state of `self.layout`.

  - Parameter flags: Optionally refresh the view for only a given set of flags. By default, this
  value is set to include all flags (i.e. `LayoutFlag.All`).
  - Parameter animated: Flag determining if the refresh should be animated from its previous
   state.
  - Note: Subclasses should override this method. The default implementation does nothing.
  */
  open func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false) {
    // NOOP. Subclasses should implement this method.
  }

  /**
   Runs a code block, allowing it to be run immediately or via a preset animation.

   - Parameter animated: Flag determining if the `code` should be animated.
   - Parameter code: The code block to run.
   */
  open func runAnimatableCode(_ animated: Bool, code: @escaping () -> Void) {
    if animated {
      let duration = layout?.config.double(for: LayoutConfig.ViewAnimationDuration) ?? 0
      if duration > 0 {
        UIView.animate(
          withDuration: duration,
          delay: 0,
          options: [.beginFromCurrentState, .allowUserInteraction],
          animations: code,
          completion: nil)

        return
      }
    }

    code()
  }
}

// MARK: - LayoutDelegate implementation

extension LayoutView: LayoutDelegate {
  public final func layoutDidChange(_ layout: Layout, withFlags flags: LayoutFlag, animated: Bool) {
    refreshView(forFlags: flags, animated: animated)
  }
}

// MARK: - Recyclable implementation

extension LayoutView: Recyclable {
  /// Prepares the view for reuse.
  public func prepareForReuse() {
    // NOTE: It is the responsibility of the superview to remove its subviews and not the other way
    // around. Thus, this method does not handle removing this view from its superview.
    layout = nil
  }
}
