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
 A default implementation of `BlockGroupLayout`.
 */
@objc(BKYDefaultBlockGroupLayout)
@objcMembers public final class DefaultBlockGroupLayout: BlockGroupLayout {
  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    var yOffset: CGFloat = 0
    var size = WorkspaceSize.zero

    // Update relative position/size of inputs
    for blockLayout in blockLayouts {
      if includeChildren {
        blockLayout.performLayout(includeChildren: true)
      }

      blockLayout.relativePosition.x = 0
      blockLayout.relativePosition.y = yOffset

      // Blocks are technically overlapping, so the actual amount that the next block is offset by
      // must take into account the size of the notch height
      yOffset += blockLayout.totalSize.height -
        blockLayout.config.workspaceUnit(for: DefaultLayoutConfig.NotchHeight)

      size = LayoutHelper.sizeThatFitsLayout(blockLayout, fromInitialSize: size)
    }

    // Update the size required for this block
    self.contentSize = size
  }
}
