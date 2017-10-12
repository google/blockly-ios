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
 Extension for adding Auto-Layout constraints to a UIView.
 */
extension UIView {
  /**
  Adds `views` as subviews to this view.

  - parameter views: The array of `UIView` objects to add.
  - parameter translatesAutoresizingMaskIntoConstraints: For every subview that is added, its
  `translatesAutoresizingMaskIntoConstraints` property is set to this value. Defaults to false.
  */
  internal func bky_addSubviews(
    _ subviews: [UIView], translatesAutoresizingMaskIntoConstraints: Bool = false)
  {
    for subview in subviews {
      subview.translatesAutoresizingMaskIntoConstraints = translatesAutoresizingMaskIntoConstraints
      addSubview(subview)
    }
  }

  /**
   Adds all layout constraints inside of `constraints` to the view.

   - parameter constraints: Array of objects of type `NSLayoutConstraint` or `[NSLayoutConstraint]`.
   */
  internal func bky_addConstraints(_ constraints: [AnyObject]) {
    for object in constraints {
      if let layoutConstraint = object as? NSLayoutConstraint {
        addConstraint(layoutConstraint)
      } else if let layoutConstraints = object as? [NSLayoutConstraint] {
        addConstraints(layoutConstraints)
      } else {
        bky_assertionFailure("Unsupported object type specified inside the `constraints` array: " +
          "\(type(of: object)). Values inside this array must be of type `NSLayoutConstraint` " +
          "or `[NSLayoutConstraint]`")
      }
    }
  }

  /**
   For each visual format constraint inside of `visualFormatConstraints`, this method creates and
   adds a layout constraint to the view via:

   NSLayoutConstraint.constraintsWithVisualFormat(visualFormat,
    options: [],
    metrics: metrics,
    views: views)

   - parameter visualFormatConstraints: Array of `String`s that follow Apple's Auto-Layout Visual
   Format language.
   - parameter metrics: Value that is passed to the `metrics| parameter of
   NSLayoutConstraint.constraintsWithVisualFormat(_options:metrics:views:).
   - parameter views: Value that is passed to the `views` parameter of
   NSLayoutConstraint.constraintsWithVisualFormat(_options:metrics:views:).
   */
  internal func bky_addVisualFormatConstraints(
    _ visualFormatConstraints: [String], metrics: [String: Any]?, views: [String: Any])
  {
    for visualFormat in visualFormatConstraints {
      let constraints = NSLayoutConstraint.constraints(withVisualFormat: visualFormat,
        options: [],
        metrics: metrics,
        views: views)
      addConstraints(constraints)
    }
  }

  /**
   Adds a `NSLayoutAttribute.Width` constraint to this view, where this view's width must equal
   a constant value.

   - parameter width: The width of the view
   - parameter priority: The priority to use for the constraint. Defaults to
   `UILayoutPriorityRequired`.
   - returns: The constraint that was added.
   */
  @discardableResult
  internal func bky_addWidthConstraint(
    _ width: CGFloat, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint
  {
    let constraint =
      NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: nil,
                         attribute: .notAnAttribute, multiplier: 1, constant: width)
    constraint.priority = priority
    addConstraint(constraint)
    return constraint
  }

  /**
   Adds a `NSLayoutAttribute.Height` constraint to this view, where this view's height must equal
   a constant value.

   - parameter height: The height of the view
   - parameter priority: The priority to use for the constraint. Defaults to
   `UILayoutPriorityRequired`.
   - returns: The constraint that was added.
   */
  @discardableResult
  internal func bky_addHeightConstraint(
    _ height: CGFloat, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint
  {
    let constraint =
      NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil,
                         attribute: .notAnAttribute, multiplier: 1, constant: height)
    constraint.priority = priority
    addConstraint(constraint)
    return constraint
  }

  /**
   Convenience method for updating constraint values related to this view.

   - parameter animated: Flag indicating whether the update of constraints should be animated. If
   set to `true`, this method calls
   `UIView.animateWithDuration(:delay:options:animations:completion:)`.
   - parameter duration: [Optional] If `animated` is set to `true`, this is the value that is passed
   to `UIView.animateWithDuration(...)` for its `duration` value. By default, this value is set to
   `0.3`.
   - parameter delay: [Optional] If `animated` is set to `true`, this is the value that is passed
   to `UIView.animateWithDuration(...)` for its `delay` value. By default, this value is set to
   `0.0`.
   - parameter options: [Optional] If `animated` is set to `true`, this is the value that is passed
   to `UIView.animateWithDuration(...)` for its `options` value. By default, this value is set to
   `.CurveEaseInOut`.
   - parameter update: A closure containing the changes to commit to the view (which is
   where your constraints should be updated). If `animated` is set to `true`, this is the value
   that is passed to `UIView.animateWithDuration(...)` for its `animations` value.
   - parameter completion: A closure that is executed when the `updateConstraints` closure ends.
   If `animated` is set to `true`, this is the value that is passed to
   `UIView.animateWithDuration(...)` for its `completion` value. By default, this value is set to
   `nil`.
   */
  internal func bky_updateConstraints(
    animated: Bool, duration: TimeInterval = 0.3, delay: TimeInterval = 0.0,
    options: UIViewAnimationOptions = UIViewAnimationOptions(), update: @escaping () -> Void,
    completion: ((Bool) -> Void)? = nil) {

    let updateView = {
      update()
      self.setNeedsUpdateConstraints()
      self.superview?.layoutIfNeeded()
    }

    if animated {
      // Force pending layout changes to complete
      self.superview?.layoutIfNeeded()

      UIView.animate(withDuration: duration, delay: delay, options: options, animations: {
        updateView()
        }, completion: completion)
    } else {
      updateView()
      completion?(true)
    }
  }
}
