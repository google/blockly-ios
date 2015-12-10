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
}
