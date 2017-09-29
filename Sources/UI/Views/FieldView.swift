/*
* Copyright 2016 Google Inc. All Rights Reserved.
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
 Abstract view for rendering a `FieldLayout`.
 */
@objc(BKYFieldView)
@objcMembers open class FieldView: LayoutView {

  // MARK: - Properties

  /// The layout object to render
  fileprivate var fieldLayout: FieldLayout? {
    return layout as? FieldLayout
  }

  // MARK: - Super

  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let fieldLayout = self.fieldLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = fieldLayout.viewFrame
      }

      // Enable/disable user interaction
      self.isUserInteractionEnabled = fieldLayout.userInteractionEnabled
    }
  }
}
