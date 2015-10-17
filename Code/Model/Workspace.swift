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
Data structure that contains `Block` instances.
*/
@objc(BKYWorkspace)
public class Workspace : NSObject {
  // MARK: - Properties

  public let isFlyout: Bool
  public let isRTL: Bool
  public let maxBlocks: Int?
  public private(set) var allBlocks = [String: Block]()

  /// The layout used for rendering this workspace
  public private(set) var layout: WorkspaceLayout?

  /// Factory responsible for returning `Layout` instances
  public let layoutFactory: LayoutFactory?

  // MARK: - Initializers

  public init(
    layoutFactory: LayoutFactory?, isFlyout: Bool, isRTL: Bool = false, maxBlocks: Int? = nil) {
      self.isFlyout = isFlyout
      self.isRTL = isRTL
      self.maxBlocks = maxBlocks
      self.layoutFactory = layoutFactory
      super.init()

      self.layout = layoutFactory?.layoutForWorkspace(self)
  }

  // MARK: - Public

  /**
  Add a given block to the workspace.

  - Parameter block: The block to add.
  */
  public func addBlock(block: Block) {
    allBlocks[block.uuid] = block
  }

  /**
  Removes a given block from the workspace.

  - Parameter block: The block to remove.
  */
  public func removeBlock(block: Block) {
    allBlocks[block.uuid] = nil

    // TODO:(vicng) Generate change event
  }
}
