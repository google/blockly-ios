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
Class that represents a single block.
*/
@objc(BKYBlock)
public class Block : NSObject {
  // MARK: - Properties

  /// A unique identifier used to identify this block for its lifetime
  public let uuid: String
  public let identifier: String
  public let category: Int
  public let colourHue: Int
  public let inputsInline: Bool
  public unowned let workspace: Workspace
  public var isInFlyout: Bool {
    return workspace.isFlyout
  }
  public let outputConnection: Connection?
  public var outputBlock: Block? {
    return outputConnection?.targetConnection?.sourceBlock
  }
  public let nextConnection: Connection?
  public var nextBlock: Block? {
    return nextConnection?.targetConnection?.sourceBlock
  }
  public let previousConnection: Connection?
  public var previousBlock: Block? {
    return previousConnection?.targetConnection?.sourceBlock
  }
  public internal(set) var inputs: [Input]
  public var tooltip: String = ""
  public var comment: String = ""
  public var helpURL: String = ""
  public var hasContextMenu: Bool = true
  public var canDelete: Bool = true
  public var canMove: Bool = true
  public var canEdit: Bool = true
  public var disabled: Bool = false

  /// Flag if this block is at the highest level in the workspace
  public var topLevel: Bool {
    return previousConnection?.targetConnection == nil && outputConnection?.targetConnection == nil
  }

  // TODO:(vicng) Potentially move these properties into a view class
  public var collapsed: Bool = false
  public var rendered: Bool = false

  /// The layout used for rendering this block
  public private(set) var layout: BlockLayout?

  // MARK: - Initializers

  /**
  To create a Block, use Block.Builder instead.
  */
  internal init(identifier: String, workspace: Workspace, category: Int,
    colourHue: Int, inputs: [Input] = [], inputsInline: Bool, outputConnection: Connection?,
    previousConnection: Connection?, nextConnection: Connection?) {
      self.uuid = NSUUID().UUIDString
      self.identifier = identifier
      self.category = category
      self.colourHue = min(max(colourHue, 0), 360)
      self.workspace = workspace
      self.inputs = inputs
      self.inputsInline = inputsInline
      self.outputConnection = outputConnection
      self.previousConnection = previousConnection
      self.nextConnection = nextConnection

      super.init()

      do {
        self.layout = try workspace.layoutFactory?.layoutForBlock(self, workspace: workspace)
      } catch let error as NSError {
        bky_assertionFailure("Could not initialize the layout: \(error)")
      }

      for input in inputs {
        input.sourceBlock = self

        if let inputLayout = input.layout {
          self.layout?.appendInputLayout(inputLayout)
        }
      }
      self.outputConnection?.sourceBlock = self
      self.previousConnection?.sourceBlock = self
      self.nextConnection?.sourceBlock = self

      // Only previous/output connectors are responsible for updating the block group 
      // layout hierarchy, not next/input connectors.
      self.previousConnection?.delegate = self
      self.outputConnection?.delegate = self

      if let connection = previousConnection {
        updateLayoutHierarchyForConnection(connection)
      }
      if let connection = outputConnection {
        updateLayoutHierarchyForConnection(connection)
      }
  }

  // MARK: - Public

  /**
  Appends an input to `self.inputs[]`.

  - Parameter input: The input to append.
  */
  public func appendInput(input: Input) {
    inputs.append(input)
  }

  // MARK: - Private

  private func updateLayoutHierarchyForConnection(connection: Connection) {
    // TODO:(vicng) Optimize re-rendering all layouts affected by this method

    if connection != previousConnection && connection != outputConnection {
      // Only previous/output connectors are responsible for updating the block group
      // layout hierarchy, not next/input connectors.
      return
    }
    guard let blockLayout = layout,
      layoutFactory = workspace.layoutFactory
      else {
        return
    }

    let oldParentLayout = blockLayout.parentBlockGroupLayout

    // Disconnect this block's layout and all subsequent block layouts from its block group layout,
    // so they can be reattached to another block group layout
    let layoutsToReattach: [BlockLayout]
    if oldParentLayout != nil {
      layoutsToReattach = oldParentLayout!.removeAllStartingFromBlockLayout(blockLayout)
    } else {
      layoutsToReattach = [blockLayout]
    }

    if connection.targetConnection != nil {
      // Block was connected to another block

      if connection == previousConnection {
        // Remove this block's old parent group layout from the workspace level
        if oldParentLayout != nil {
          workspace.layout?.removeBlockGroupLayout(oldParentLayout!)
        }

        // Reattach block layouts to the target block's group layout
        connection.targetConnection?.sourceBlock.layout?.parentBlockGroupLayout?.appendBlockLayouts(
          layoutsToReattach)
      } else if connection == outputConnection {
        // Reattach block layouts to target input's block group layout
        connection.targetConnection?.sourceInput?.layout?.blockGroupLayout.appendBlockLayouts(
          layoutsToReattach)
      }
    } else {
      // Block was disconnected and added to the workspace level

      // Keep track of the current absolute position of the block layout as this will be the
      // `relativePosition` for the new block group layout
      let currentAbsolutePosition = blockLayout.absolutePosition

      // Reattach block layouts to a new block group layout
      do {
        let blockGroupLayout = try layoutFactory.blockGroupLayoutForWorkspace(workspace)
        blockGroupLayout.relativePosition = currentAbsolutePosition
        blockGroupLayout.appendBlockLayouts(layoutsToReattach)
        // TODO:(vicng) This is heavy-handed, optimize this.
        blockGroupLayout.updateLayout()

        // Add this new block group layout to the workspace level
        workspace.layout?.appendBlockGroupLayout(blockGroupLayout)
      } catch let error as NSError {
        bky_assertionFailure("Could not create a new BlockGroupLayout: \(error)")
      }
    }
  }
}

// MARK: - ConnectionDelegate

extension Block: ConnectionDelegate {
  public func didChangeTargetForConnection(connection: Connection) {
    updateLayoutHierarchyForConnection(connection)
  }
}

// TODO:(vicng) Rename this class to BlocklyError
/**
Class used when errors occur inside `Block` methods.
*/
@objc(BKYBlockError)
public class BlockError: NSError {
  // MARK: - Static Properties

  /// Domain to use when throwing an error from this class
  public static let Domain = "com.google.blockly.Block"

  // MARK: - Enum - Code
  @objc
  public enum BKYBlockErrorCode: Int {
    case InvalidBlockDefinition = 100,
      LayoutNotFound = 200,
      ViewNotFound = 300
  }
  public typealias Code = BKYBlockErrorCode

  // MARK: - Initializers

  public init(_ code: Code, _ description: String) {
    super.init(
      domain: BlockError.Domain,
      code: code.rawValue,
      userInfo: [NSLocalizedDescriptionKey : description])
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
