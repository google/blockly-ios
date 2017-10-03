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
@objcMembers open class WorkspaceFlow: Workspace {
  /// Defines information on how each item should be laid out in the layout.
  @objc(BKYWorkspaceFlowItem)
  @objcMembers public class Item: NSObject {
    /// The root block for this item.
    public fileprivate(set) var rootBlock: Block?
    /// The gap between the previous item and this one.
    public fileprivate(set) var gap: CGFloat?

    fileprivate init(rootBlock: Block) {
      self.rootBlock = rootBlock
    }
    fileprivate init(gap: CGFloat) {
      self.gap = gap
    }
  }

  // MARK: - Properties

  /// List of all elements that have been added
  public fileprivate(set) var items = [Item]()

  // MARK: - Super

  open override func addBlockTree(_ rootBlock: Block) throws {
    try super.addBlockTree(rootBlock)

    items.append(Item(rootBlock: rootBlock))
    layout?.updateLayoutUpTree()
  }

  open override func removeBlockTree(_ rootBlock: Block) throws {
    try super.removeBlockTree(rootBlock)

    // Remove item for this block (by only keeping blocks that don't match this rootBlock)
    items = items.filter({ $0.rootBlock != rootBlock })
    layout?.updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Adds a gap between the last block that was added and the next block that will be added.

   - parameter gap: The gap space, expressed as a Workspace coordinate system unit
   - note: Trailing gaps are truncated and ignored on layout.
   */
  open func addGap(_ gap: CGFloat = 24) {
    items.append(Item(gap: gap))
    layout?.updateLayoutUpTree()
  }
}
