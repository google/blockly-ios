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
 Extends the `UIView` class with convenience functions for Blockly.
 */
extension UIView {
  // MARK: - Helpers

  /**
  Removes all gesture recognizers from the view.
  */
  internal func bky_removeAllGestureRecognizers() {
    let gestureRecognizers = (self.gestureRecognizers ?? [])
    for gestureRecognizer in gestureRecognizers {
      removeGestureRecognizer(gestureRecognizer)
    }
  }

  /**
   Traverses up the view tree and returns the first ancestor that is of a given type.

   - parameter type: The type of `UIView` to find.
   - returns: The first ancestor of the given `type`, or `nil` if none could be found.
   */
  internal final func bky_firstAncestor<T>(ofType type: T.Type? = nil) -> T? where T: UIView {
    var parent = self.superview

    while parent != nil {
      if let typedParent = parent as? T {
        return typedParent
      }
      parent = parent?.superview
    }

    return nil
  }

  /**
   Returns whether this view is a descendant of a given `UIView`.

   - parameter: The `UIView` to check.
   - returns: `true` if this view is a descendant of `otherView`. `false` otherwise.
   */
  internal final func bky_isDescendant(of otherView: UIView) -> Bool {
    var parent = self.superview

    while parent != nil {
      if parent === otherView {
        return true
      }
      parent = parent?.superview
    }

    return false
  }
}
