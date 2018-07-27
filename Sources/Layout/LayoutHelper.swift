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
Helper class for doing layout calculatinos.
*/
@objc(BKYLayoutHelper)
@objcMembers internal class LayoutHelper: NSObject {

  /**
  Ensure the given layout will fit within a given size, increasing the size if necessary.

  - parameter layout: The layout to accommodate
  - parameter size: The initial workspace size
  - returns: A workspace size that now accommodates the layout.
  */
  internal static func sizeThatFitsLayout
    (_ layout: Layout, fromInitialSize size: WorkspaceSize) -> WorkspaceSize {
    return WorkspaceSize(
      width: max(size.width, layout.relativePosition.x + layout.totalSize.width),
      height: max(size.height, layout.relativePosition.y + layout.totalSize.height))
  }
}
