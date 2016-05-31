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
 Factory for instantiating new blocks by name. Blocks can be loaded in from a
 JSON file or be added manually.
 */
@objc(BKYBlockFactory)
public class BlockFactory : NSObject {

  internal var _blockBuilders = Dictionary<String, Block.Builder>()

  // MARK: - Initializers

  /**
   Creates a BlockFactory.
   */
  public override init() {
  }

  /**
   Creates a BlockFactory with blocks loaded from a json file.

   - Parameter jsonPath: Path to file containing blocks in JSON.
   - Parameter bundle: The bundle to find the json file. If nil, NSBundle.mainBundle() is used.
   - Throws:
   `BlocklyError`: Occurs if any of the blocks are invalid.
   */
  public init(jsonPath: String, bundle: NSBundle? = nil) throws {
    super.init()

    try loadFromJSONPaths([jsonPath], bundle: bundle)
  }

  /**
   Creates a BlockFactory with blocks loaded from a list of json files.

   - Parameter jsonPaths: List of paths to files containing blocks in JSON.
   - Parameter bundle: The bundle to find the json files. If nil, NSBundle.mainBundle() is used.
   - Throws:
   `BlocklyError`: Occurs if any of the blocks are invalid.
   */
  public init(jsonPaths: [String], bundle: NSBundle? = nil) throws {
    super.init()

    try loadFromJSONPaths(jsonPaths, bundle: bundle)
  }

  /**
   Loads blocks from a list of json files.

   - Parameter jsonPaths: List of paths to files containing blocks in JSON.
   - Parameter bundle: The bundle to find the json file. If nil, NSBundle.mainBundle() is used.
   */
  public func loadFromJSONPaths(jsonPaths: [String], bundle: NSBundle? = nil) throws {
    let aBundle = (bundle ?? NSBundle.mainBundle())

    for jsonPath in jsonPaths {
      guard let path = aBundle.pathForResource(jsonPath, ofType: nil) else {
        throw BlocklyError(.FileNotFound, "Could not find \"\(jsonPath)\" in bundle [\(aBundle)]")
      }
      let jsonString = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
      let json = try JSONHelper.JSONArrayFromString(jsonString)
      for blockJson in json {
        let blockBuilder = try Block.builderFromJSON(blockJson as! [String : AnyObject])
        // Ensure the builder is valid
        try blockBuilder.build()

        // Save the block
        _blockBuilders[blockBuilder.name] = blockBuilder
      }
    }
  }

  // MARK: - Public

  /**
   Creates a new instance of a block with the given name, adds it to a specific workspace, and
   returns it.

   - Parameter blockName: The name of the block to obtain.
   - Parameter workspace: The workspace that should own the new block.
   - Throws:
   `BlocklyError`: Occurs if the block builder is missing any required pieces.
   - Returns: A new block if the name is known, nil otherwise.
   */
  public func addBlock(blockName: String, toWorkspace workspace: Workspace) throws -> Block? {
    guard let block = try buildBlock(blockName) else {
      return nil
    }
    try workspace.addBlockTree(block)
    return block
  }

  /**
   Creates a new instance of a block with the given name and returns it.

   - Parameter blockName: The name of the block to build.
   - Parameter uuid: [Optional] The uuid to assign the block. If nil, a new uuid is automatically
   assigned to the block.
   - Parameter shadow: [Optional] Specifies if the resulting block should be a shadow block.
   The default value is `false`.
   - Throws:
   `BlocklyError`: Occurs if the block builder is missing any required pieces.
   - Returns: A new block if the name is known, nil otherwise.
   */
  public func buildBlock(blockName: String, uuid: String? = nil, shadow: Bool = false) throws
    -> Block?
  {
    return try _blockBuilders[blockName]?.build(uuid: uuid, shadow: shadow)
  }
}
