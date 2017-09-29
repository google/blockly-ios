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
 Abstract view for rendering a `BlockLayout`.
 */
@objc(BKYBlockView)
@objcMembers open class BlockView: LayoutView {
  // MARK: - Properties

  /// Layout object to render
  open var blockLayout: BlockLayout? {
    return layout as? BlockLayout
  }

  // MARK: - Initializers

  /// Default initializer for block views.
  public required init() {
    super.init(frame: CGRect.zero)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRect.zero

    for subview in subviews {
      subview.removeFromSuperview()
    }
  }
}
