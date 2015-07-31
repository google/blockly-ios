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

// TODO(vicng): The Obj-C bridging header isn't generated properly when a class marked with @objc
//     has an extension (ie. Block+JSON.swift). This looks like a bug with Xcode 7.
//     When it's fixed, replace "@objc" with "@objc(BKYBlock)".
@objc
public class Block : NSObject {
  // MARK: - Properties

  public let identifier: String
  public let name: String
  public let category: Int
  public let colourHue: Int
  public let outputConnection: Connection?
  public let nextConnection: Connection?
  public let previousConnection: Connection?
  public let inputList: [Input]
  public let inputsInline: Bool
  public unowned let workspace: Workspace
  public var isInFlyout: Bool {
    return workspace.isFlyout
  }
  public var childBlocks: [Block] = []
  public weak var parentBlock: Block?
  public var tooltip: String = ""
  public var comment: String = ""
  public var helpURL: String = ""
  public var hasContextMenu: Bool = true
  public var canDelete: Bool = true
  public var canMove: Bool = true
  public var canEdit: Bool = true
  public var collapsed: Bool = false
  public var disabled: Bool = false
  public var rendered: Bool = false
  public var position: CGPoint = CGPointZero

  // MARK: - Initializers

  /** To create a Block, use Block.Builder instead. */
  internal init(identifier: String, name: String, workspace: Workspace, category: Int,
    colourHue: Int, inputList: [Input] = [], inputsInline: Bool,
    outputConnection: Connection? = nil, nextConnection: Connection? = nil,
    previousConnection: Connection? = nil) {
      self.identifier = identifier
      self.name = name
      self.category = category
      self.colourHue = colourHue
      self.workspace = workspace
      self.inputList = inputList
      self.inputsInline = inputsInline
      self.outputConnection = outputConnection
      self.nextConnection = nextConnection
      self.previousConnection = previousConnection
  }
}

@objc
public enum BlockErrorCode: Int {
  case InvalidBlockDefinition = 100
}

@objc
public class BlockError: NSError {
  /** Domain to use when throwing an error from this class */
  static let Domain = "com.google.blockly.Block"

  public init(_ code: BlockErrorCode, _ description: String) {
    super.init(
      domain: BlockError.Domain,
      code: code.rawValue,
      userInfo: [NSLocalizedDescriptionKey : description])
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
