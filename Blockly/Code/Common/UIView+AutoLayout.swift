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

  - Parameter views: The array of `UIView` objects to add.
  - Parameter translatesAutoresizingMaskIntoConstraints: For every subview that is added, its
  `translatesAutoresizingMaskIntoConstraints` property is set to this value. Defaults to false.
  */
  internal func bky_addSubviews(
    subviews: [UIView], translatesAutoresizingMaskIntoConstraints: Bool = false)
  {
    for subview in subviews {
      subview.translatesAutoresizingMaskIntoConstraints = translatesAutoresizingMaskIntoConstraints
      addSubview(subview)
    }
  }

  /**
   Adds all layout constraints inside of `constraints` to the view.

   - Parameter constraints: Array of objects of type `NSLayoutConstraint` or `[NSLayoutConstraint]`.
   */
  internal func bky_addConstraints(constraints: [AnyObject]) {
    for object in constraints {
      if let layoutConstraint = object as? NSLayoutConstraint {
        addConstraint(layoutConstraint)
      } else if let layoutConstraints = object as? [NSLayoutConstraint] {
        addConstraints(layoutConstraints)
      } else {
        bky_assertionFailure("Unsupported object type specified inside the `constraints` array: " +
          "\(object.dynamicType). Values inside this array must be of type `NSLayoutConstraint` " +
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

   - Parameter visualFormatConstraints: Array of `String`s that follow Apple's Auto-Layout Visual
   Format language.
   - Parameter metrics: Value that is passed to the `metrics| parameter of
   NSLayoutConstraint.constraintsWithVisualFormat(_options:metrics:views:).
   - Parameter views: Value that is passed to the `views` parameter of
   NSLayoutConstraint.constraintsWithVisualFormat(_options:metrics:views:).
   */
  internal func bky_addVisualFormatConstraints(
    visualFormatConstraints: [String], metrics: [String: AnyObject]?, views: [String: AnyObject])
  {
    for visualFormat in visualFormatConstraints {
      let constraints = NSLayoutConstraint.constraintsWithVisualFormat(visualFormat,
        options: [],
        metrics: metrics,
        views: views)
      addConstraints(constraints)
    }
  }

  /**
   Adds a `NSLayoutAttribute.Width` constraint to this view, where this view's width must equal
   a constant value.

   - Parameter width: The width of the view
   - Parameter priority: The priority to use for the constraint. Defaults to
   `UILayoutPriorityRequired`.
   - Returns: The constraint that was added.
   */
  internal func bky_addWidthConstraint(
    width: CGFloat, priority: UILayoutPriority = UILayoutPriorityRequired) -> NSLayoutConstraint
  {
    let constraint =
      NSLayoutConstraint(item: self, attribute: .Width, relatedBy: .Equal, toItem: nil,
                         attribute: .NotAnAttribute, multiplier: 1, constant: width)
    constraint.priority = priority
    addConstraint(constraint)
    return constraint
  }

  /**
   Adds a `NSLayoutAttribute.Height` constraint to this view, where this view's height must equal
   a constant value.

   - Parameter height: The height of the view
   - Parameter priority: The priority to use for the constraint. Defaults to
   `UILayoutPriorityRequired`.
   - Returns: The constraint that was added.
   */
  internal func bky_addHeightConstraint(
    height: CGFloat, priority: UILayoutPriority = UILayoutPriorityRequired) -> NSLayoutConstraint
  {
    let constraint =
      NSLayoutConstraint(item: self, attribute: .Height, relatedBy: .Equal, toItem: nil,
                         attribute: .NotAnAttribute, multiplier: 1, constant: height)
    constraint.priority = priority
    addConstraint(constraint)
    return constraint
  }

  /**
   Convenience method for updating constraint values related to this view.

   - Parameter animated: Flag indicating whether the update of constraints should be animated. If
   set to `true`, this method calls
   `UIView.animateWithDuration(:delay:options:animations:completion:)`.
   - Parameter duration: [Optional] If `animated` is set to `true`, this is the value that is passed
   to `UIView.animateWithDuration(...)` for its `duration` value. By default, this value is set to
   `0.3`.
   - Parameter delay: [Optional] If `animated` is set to `true`, this is the value that is passed
   to `UIView.animateWithDuration(...)` for its `delay` value. By default, this value is set to
   `0.0`.
   - Parameter options: [Optional] If `animated` is set to `true`, this is the value that is passed
   to `UIView.animateWithDuration(...)` for its `options` value. By default, this value is set to
   `.CurveEaseInOut`.
   - Parameter update: A closure containing the changes to commit to the view (which is
   where your constraints should be updated). If `animated` is set to `true`, this is the value
   that is passed to `UIView.animateWithDuration(...)` for its `animations` value.
   - Parameter completion: A closure that is executed when the `updateConstraints` closure ends.
   If `animated` is set to `true`, this is the value that is passed to
   `UIView.animateWithDuration(...)` for its `completion` value. By default, this value is set to
   `nil`.
   */
  internal func bky_updateConstraints(
    animated animated: Bool, duration: NSTimeInterval = 0.3, delay: NSTimeInterval = 0.0,
    options: UIViewAnimationOptions = .CurveEaseInOut, update: () -> Void,
    completion: ((Bool) -> Void)? = nil) {

    let updateView = {
      update()
      self.setNeedsUpdateConstraints()
      self.superview?.layoutIfNeeded()
    }

    if animated {
      // Force pending layout changes to complete
      self.superview?.layoutIfNeeded()

      UIView.animateWithDuration(duration, delay: delay, options: options, animations: {
        updateView()
        }, completion: completion)
    } else {
      updateView()
      completion?(true)
    }
  }
}
