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
 Protocol for handling popover requests that occur from a `LayoutView`.
 */
@objc(BKYLayoutPopoverDelegate)
public protocol LayoutPopoverDelegate {
  /**
   Event is called when a layout view requests to present a view controller.

   - parameter layoutView: The `LayoutView` that made the request
   - parameter viewController: The `UIViewController` to present
   */
  func layoutView(_ layoutView: LayoutView,
                 requestedToPresentViewController viewController: UIViewController)

  /**
   Event that is called when a layout view requests to present a view controller as a popover.

   - parameter layoutView: The `LayoutView` that made the request
   - parameter viewController: The `UIViewController` to present
   - parameter fromView: The `UIView` where the popover should pop up from
   - parameter presentationDelegate: A `UIPopoverPresentationControllerDelegate` that should
   be notified when presentation events are fired.
   - returns: `true` if the `viewController` was presented. `false` otherwise.
   */
  @discardableResult
  func layoutView(_ layoutView: LayoutView,
                 requestedToPresentPopoverViewController viewController: UIViewController,
                 fromView: UIView,
                 presentationDelegate: UIPopoverPresentationControllerDelegate?) -> Bool

  /**
   Event is called when a layout view requests to dismiss a view controller.

   - parameter layoutView: The `LayoutView` that made the request.
   - parameter viewController: The `UIViewController` to dismiss.
   - parameter animated: Pass `true` to animate the transition.
   */
  func layoutView(_ layoutView: LayoutView,
                  requestedToDismissPopoverViewController viewController: UIViewController,
                  animated: Bool)
}

/**
Abstract class for rendering a `UIView` backed by a `Layout`.
*/
@objc(BKYLayoutView)
@objcMembers open class LayoutView: UIView {

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
        ViewManager.shared.uncacheView(forLayout: previousValue)
      }

      if let newValue = layout {
        newValue.delegate = self
        // Automatically track this view in the ViewManager
        ViewManager.shared.cacheView(self, forLayout: newValue)

        refreshView()
      } else {
        prepareForReuse()
      }
    }
  }

  /// The delegate for handling popover requests that occur from this view
  public weak var popoverDelegate: LayoutPopoverDelegate?

  // MARK: - Public

  /**
  Refreshes the view based on the current state of `self.layout`.

  - parameter flags: Optionally refresh the view for only a given set of flags. By default, this
  value is set to include all flags (i.e. `LayoutFlag.All`).
  - parameter animated: Flag determining if the refresh should be animated from its previous
   state.
  - note: Subclasses should override this method. The default implementation does nothing.
  */
  open func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false) {
    // NOOP. Subclasses should implement this method.
  }

  /**
   Runs a code block, allowing it to be run immediately or via a preset animation.

   - parameter animated: Flag determining if the `code` should be animated.
   - parameter code: The code block to run.
   */
  open func runAnimatableCode(_ animated: Bool, code: @escaping () -> Void) {
    runAnimatableCode(animated, code: code, completion: nil)
  }

  /**
   Runs a code block, allowing it to be run immediately or via a preset animation.

   - parameter animated: Flag determining if the `code` should be animated.
   - parameter code: The code block to run.
   - parameter completion: The completion block to run after the code block has finished running.
   This block has no return value and takes a single Boolean argument that indicates whether or not
   the animations actually finished before the completion handler was called.
  */
  open func runAnimatableCode(
    _ animated: Bool, code: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
    if animated {
      let duration = layout?.config.double(for: LayoutConfig.ViewAnimationDuration) ?? 0
      if duration > 0 {
        UIView.animate(
          withDuration: duration,
          delay: 0,
          options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
          animations: code,
          completion: completion)

        return
      }
    }

    code()
    completion?(true)
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
  public func prepareForReuse() {
    // NOTE: It is the responsibility of the superview to remove its subviews and not the other way
    // around. Thus, this method does not handle removing this view from its superview.
    layout = nil
  }
}
