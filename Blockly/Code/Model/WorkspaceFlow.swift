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
 Subclass of Workspace that should be used to populate a `WorkspaceFlowLayout`.
 */
@objc(BKYWorkspaceFlow)
public class WorkspaceFlow: Workspace {
  /// Defines information on how each item should be laid out in the layout.
  public class Item {
    public private(set) var rootBlock: Block?
    public private(set) var gap: CGFloat?

    private init(rootBlock: Block) {
      self.rootBlock = rootBlock
    }
    private init(gap: CGFloat) {
      self.gap = gap
    }
  }

  // MARK: - Properties

  /// List of all elements that have been added
  public private(set) var items = [Item]()

  // MARK: - Super

  public override func addBlockTree(rootBlock: Block) throws {
    items.append(Item(rootBlock: rootBlock))
    try super.addBlockTree(rootBlock)
  }

  public override func removeBlockTree(rootBlock: Block) {
    // Remove item for this block (by only keeping blocks that don't match this rootBlock)
    items = items.filter({ $0.rootBlock != rootBlock })
    super.removeBlockTree(rootBlock)
  }

  // MARK: - Public

  /**
   Adds a gap between the last block that was added and the next block that will be added.

   - Parameter gap: The gap space, expressed as a Workspace coordinate system unit
   - Note: Trailing gaps are truncated and ignored on layout.
   */
  public func addGap(gap: CGFloat = 24) {
    items.append(Item(gap: gap))
    layout?.updateLayoutUpTree()
  }
}
