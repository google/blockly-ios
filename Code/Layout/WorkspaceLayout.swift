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

/*
Stores information on how to render and position a |Block| on-screen.
*/
@objc(BKYWorkspaceLayout)
public class WorkspaceLayout: Layout {
  // MARK: - Properties

  /// The `Workspace` to layout
  public let workspace: Workspace

  /// The corresponding `BlockGroupLayout` objects seeded by each `Block` inside of
  /// `self.workspace.blocks[]`.
  public private(set) var blockGroupLayouts = [BlockGroupLayout]()

  // MARK: - Initializers

  public required init(workspace: Workspace) {
    self.workspace = workspace
    super.init(parentLayout: nil)
    self.workspace.delegate = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return blockGroupLayouts
  }

  public override func layoutChildren() {
    // Update relative position/size of blocks
    for blockGroupLayout in blockGroupLayouts {
      blockGroupLayout.layoutChildren()
    }

    // Update size required for the workspace
    self.size = sizeThatFitsForChildLayouts()
  }

  // MARK: - Public

  /**
  Returns all descendants of this layout that are of type |BlockLayout|.
  */
  public func allBlockLayoutDescendants() -> [BlockLayout] {
    var descendants = [BlockLayout]()
    var layoutsToProcess = blockGroupLayouts

    while !layoutsToProcess.isEmpty {
      let blockGroupLayout = layoutsToProcess.removeFirst()
      descendants += blockGroupLayout.blockLayouts

      for blockLayout in blockGroupLayout.blockLayouts {
        for inputLayout in blockLayout.inputLayouts {
          layoutsToProcess.append(inputLayout.blockGroupLayout)
        }
      }
    }

    return descendants
  }

  /**
  Appends a blockGroupLayout to `self.blockGroupLayouts` and sets its `parentLayout` to this
  instance.

  - Parameter blockGroupLayout: The `BlockGroupLayout` to append.
  */
  public func appendBlockGroupLayout(blockGroupLayout: BlockGroupLayout) {
    blockGroupLayout.parentLayout = self
    blockGroupLayouts.append(blockGroupLayout)
  }

  /**
  Removes `self.blockGroupLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter blockGroupLayout: The `BlockGroupLayout` to append.
  - Returns: The `BlockGroupLayout` that was removed.
  */
  public func removeBlockGroupLayoutAtIndex(index: Int) -> BlockGroupLayout {
    let blockGroupLayout = blockGroupLayouts.removeAtIndex(index)
    blockGroupLayout.parentLayout = nil
    return blockGroupLayout
  }
}

// MARK: - WorkspaceDelegate

extension WorkspaceLayout: WorkspaceDelegate {
  public func workspaceDidChange(workspace: Workspace) {
    // TODO:(vicng) Potentially generate an event to update the corresponding view
  }
}
