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
Point in the Workspace coordinate system (which is separate from the UIView coordinate system).
*/
public typealias WorkspacePoint = CGPoint
public var WorkspacePointZero: WorkspacePoint { return CGPointZero }
public func WorkspacePointMake(x: CGFloat, _ y: CGFloat) -> WorkspacePoint {
  return CGPointMake(x, y)
}

/**
Size in the Workspace coordinate system (which is separate from the UIView coordinate system).
*/
public typealias WorkspaceSize = CGSize
public var WorkspaceSizeZero: WorkspaceSize { return CGSizeZero }
public func WorkspaceSizeMake(width: CGFloat, _ height: CGFloat) -> WorkspaceSize {
  return CGSizeMake(width, height)
}

/**
Edge insets in the Workspace coordinate system (which is separate from the UIView coordinate
system).
*/
public typealias WorkspaceEdgeInsets = UIEdgeInsets
public var WorkspaceEdgeInsetsZero: WorkspaceEdgeInsets { return UIEdgeInsetsZero }
public func WorkspaceEdgeInsetsMake(
  top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) -> WorkspaceEdgeInsets {
  return UIEdgeInsetsMake(top, left, bottom, right)
}

/**
 Protocol for events that occur on a `Workspace` instance.
 */
@objc(BKYWorkspaceDelegate)
public protocol WorkspaceDelegate: class {
  /**
   Event that is called when a block has been added to a workspace.

   - Parameter workspace: The workspace that added a block.
   - Parameter block: The block that was added.
  */
  func workspace(workspace: Workspace, didAddBlock: Block)
}

/**
Data structure that contains `Block` instances.
*/
@objc(BKYWorkspace)
public class Workspace : NSObject {
  // MARK: - Properties

  public let rtl: Bool
  public let maxBlocks: Int?
  public private(set) var allBlocks = [String: Block]()

  /// The delegate for events that occur in this workspace
  public weak var delegate: WorkspaceDelegate?

  /// Convenience property for accessing `self.delegate` as a `WorkspaceLayout`
  public var layout: WorkspaceLayout? {
    return self.delegate as? WorkspaceLayout
  }

  // MARK: - Initializers

  /**
  Initializer for a Workspace.

  - Parameter rtl: Optional parameter for setting `self.rtl`. If no value is specified, `self.rtl`
  is automatically set using the system's layout direction.
  - Parameter maxBlocks: Optional parameter for setting `self.maxBlocks`.
  */
  public init(rtl: Bool? = nil, maxBlocks: Int? = nil) {
    self.rtl =
      rtl ?? (UIApplication.sharedApplication().userInterfaceLayoutDirection == .RightToLeft)
    self.maxBlocks = maxBlocks
    super.init()
  }

  // MARK: - Public

  public func topLevelBlocks() -> [Block] {
    return allBlocks.values.filter({ $0.topLevel })
  }

  // MARK: - Internal

  /**
  Add a given block to the workspace.

  - Parameter block: The block to add.
  - Returns: True if the block was added.  False if the block was not added (because it was already
  in the workspace).
  */
  internal func addBlock(block: Block) -> Bool {
    if allBlocks[block.uuid] != nil {
      // Block already exists, return false
      return false
    }

    allBlocks[block.uuid] = block

    delegate?.workspace(self, didAddBlock: block)

    return true
  }

  /**
  Removes a given block from the workspace.

  - Parameter block: The block to remove.
  */
  internal func removeBlock(block: Block) {
    allBlocks[block.uuid] = nil

    // TODO:(vicng) Generate change event
  }

  /**
  Returns if this block has been added to the workspace.
  */
  internal func containsBlock(block: Block) -> Bool {
    return (allBlocks[block.uuid] != nil)
  }
}
