/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

import UIKit

/**
 Provides helper methods for `UIPopoverPresentationController`.
 */
extension UIPopoverPresentationController {
  /**
   By default, there is no way to prioritize values within `permittedArrowDirections`.
   This method tries to accomplish this by setting `permittedArrowDirections` to a single direction
   from a prioritized list of given arrow directions.

   An arrow direction is set if the popover can fully fit inside the container view, using that
   direction. If none of the given directions fit, `permittedArrowDirections` remains unchanged.

   - note: This method will only work properly if called within the delegate method
   `UIPopoverPresentationControllerDelegate#prepareForPopoverPresentation(:)` and if
   `presentedViewController.preferredContentSize` is set to a non-zero value.
   - parameter arrowDirections: A list of prioritized `UIPopoverArrowDirection` values.
   - parameter rtl: If set to `true`, `arrowDirections` is interpreted such that
   `UIPopoverArrowDirection.left` and `UIPopoverArrowDirection.right` are reversed. Otherwise,
   `arrowDirections` is interpreted as-is.
   */
  public func bky_prioritizeArrowDirections(
    _ arrowDirections: Array<UIPopoverArrowDirection>, rtl: Bool) {
    let contentSize = presentedViewController.preferredContentSize

    guard let containerView = self.containerView,
      contentSize != .zero else {
      return
    }

    var containerBounds = containerView.bounds

    // Take into account the safe area.
    if #available(iOS 11.0, *) {
      containerBounds = UIEdgeInsetsInsetRect(containerBounds, containerView.safeAreaInsets)
    }

    // Take into account the navigation bar if the presenting controller is a
    // `UINavigationController`.
    if let navigationController = presentingViewController as? UINavigationController,
      !navigationController.navigationBar.isHidden {
      containerBounds.origin.y += navigationController.navigationBar.bounds.height
      containerBounds.size.height -= navigationController.navigationBar.bounds.height
    }

    // Use a hardcoded value for the popover arrow size, since it isn't exposed in the iOS SDK
    // (the size hasn't changed since iOS 8.x).
    let arrowSize: CGFloat = 15
    let rectRelativeToContainer = containerView.convert(sourceRect, from: sourceView)

    // From the arrow directions, figure out which popover direction would fit inside the
    // container view.
    for direction in arrowDirections {
      var arrowDirection = direction
      if rtl && arrowDirection == .left {
        arrowDirection = .right
      } else if rtl && arrowDirection == .right {
        arrowDirection = .left
      }

      if arrowDirection == .down &&
        (rectRelativeToContainer.minY - arrowSize - contentSize.height) >= containerBounds.minY &&
        contentSize.width <= containerBounds.width  {
        permittedArrowDirections = .down
        break
      } else if arrowDirection == .up &&
        (rectRelativeToContainer.maxY + arrowSize + contentSize.height) <= containerBounds.maxY &&
        contentSize.width <= containerBounds.width {
        permittedArrowDirections = .up
        break
      } else if arrowDirection == .right &&
        (rectRelativeToContainer.minX - arrowSize - contentSize.width) >= containerBounds.minX &&
        contentSize.height <= containerBounds.height {
        permittedArrowDirections = .right
        break
      } else if arrowDirection == .left &&
        (rectRelativeToContainer.maxX + arrowSize + contentSize.width) <= containerBounds.maxX &&
        contentSize.height <= containerBounds.height {
        permittedArrowDirections = .left
        break
      }
    }
  }
}
