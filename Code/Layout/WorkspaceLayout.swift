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

  public let workspace: Workspace
  public var blockLayouts = [BlockLayout]()

  // MARK: - Initializers

  public required init(workspace: Workspace) {
    self.workspace = workspace
    super.init(parentLayout: nil)
    self.workspace.delegate = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return blockLayouts
  }

  public override func layoutChildren() {
    // Update relative position/size of blocks
    for blockLayout in blockLayouts {
      blockLayout.layoutChildren()
    }

    // Update size required for the workspace
    self.size = sizeThatFitsForChildLayouts()
  }

  // MARK: - Public

  /** Returns all descendants of this layout that are of type |BlockLayout|. */
  public func allBlockLayoutDescendants() -> [BlockLayout] {
    var descendants = [BlockLayout]()
    var blockLayoutsToProcess = blockLayouts

    while !blockLayoutsToProcess.isEmpty {
      let blockLayout = blockLayoutsToProcess.removeFirst()
      descendants.append(blockLayout)
      blockLayoutsToProcess += blockLayout.childBlockLayouts
    }

    return descendants
  }
}

// MARK: - WorkspaceDelegate

extension WorkspaceLayout: WorkspaceDelegate {
  public func workspaceDidChange(workspace: Workspace) {
    // TODO:(vicng) Potentially generate an event to update the corresponding view
  }
}
