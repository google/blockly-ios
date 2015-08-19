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

import UIKit

// MARK: -

/*
Stores information on how to render and position a |Block| on-screen.
*/
@objc(BKYBlockLayout)
public class BlockLayout: Layout {
  // MARK: - Properties

  public let block: Block
  public var childBlockLayouts = [BlockLayout]()
  public var inputLayouts = [InputLayout]()

  // MARK: - Initializers

  public required init(block: Block, parentLayout: Layout?) {
    self.block = block
    super.init(parentLayout: parentLayout)
    self.block.delegate = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return (childBlockLayouts as [Layout]) + (inputLayouts as [Layout])
  }

  public override func layoutChildren() {
    // Update relative position/size of blocks
    for blockLayout in childBlockLayouts {
      blockLayout.layoutChildren()

      // TODO:(vicng) Figure out new positions for each block
    }

    // Update relative position/size of inputs
    for inputLayout in inputLayouts {
      inputLayout.layoutChildren()

      // TODO:(vicng) Figure out new positions for each input
    }

    // Update the size required for this block
    var newSize = sizeThatFitsForChildLayouts()

    // TODO:(vicng) Determine the correct amount of padding needed for this layout.
    //      For now, (100,100) has been added as a quick test.
    newSize.height += 100
    newSize.width += 100

    if self.size != newSize {
      self.size = newSize
    }
  }
}

// MARK: - BlockDelegate

extension BlockLayout: BlockDelegate {
  public func blockDidChange(block: Block) {
    // TODO:(vicng) Potentially generate an event to update the corresponding view
  }
}
