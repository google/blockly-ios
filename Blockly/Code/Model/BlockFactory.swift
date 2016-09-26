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
  public init(jsonPath: String, bundle: Bundle? = nil) throws {
    super.init()

    try load(jsonPaths: [jsonPath], bundle: bundle)
  }

  /**
   Creates a BlockFactory with blocks loaded from a list of json files.

   - Parameter jsonPaths: List of paths to files containing blocks in JSON.
   - Parameter bundle: The bundle to find the json files. If nil, NSBundle.mainBundle() is used.
   - Throws:
   `BlocklyError`: Occurs if any of the blocks are invalid.
   */
  public init(jsonPaths: [String], bundle: Bundle? = nil) throws {
    super.init()

    try load(jsonPaths: jsonPaths, bundle: bundle)
  }

  // MARK: - Public

  /**
   Loads blocks from a list of json files.

   - Parameter jsonPaths: List of paths to files containing blocks in JSON.
   - Parameter bundle: The bundle to find the json file. If nil, NSBundle.mainBundle() is used.
   */
  public func load(jsonPaths: [String], bundle: Bundle? = nil) throws {
    let aBundle = (bundle ?? Bundle.main)

    for jsonPath in jsonPaths {
      guard let path = aBundle.path(forResource: jsonPath, ofType: nil) else {
        throw BlocklyError(.fileNotFound, "Could not find \"\(jsonPath)\" in bundle [\(aBundle)]")
      }
      let jsonString = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
      let json = try JSONHelper.makeJSONArray(string: jsonString)
      for blockJson in json {
        let blockBuilder = try Block.makeBuilder(json: blockJson as! [String : Any])
        // Ensure the builder is valid
        _ = try blockBuilder.makeBlock()

        // Save the block
        _blockBuilders[blockBuilder.name] = blockBuilder
      }
    }
  }

  /**
   Creates and returns a new `Block` with the given name.

   - Parameter name: The name of the block to build.
   - Throws:
   `BlocklyError`: Occurs if the block builder for the given name could not be found or if the
   block builder is missing any required pieces.
   - Returns: A new `Block`.
   */
  public func makeBlock(name: String) throws -> Block {
    return try makeBlock(name: name, shadow: false, uuid: nil)
  }

  /**
   Creates and returns a new `Block` with the given name.

   - Parameter name: The name of the block to build.
   - Parameter shadow: Specifies if the resulting block should be a shadow block.
   - Parameter uuid: [Optional] The uuid to assign the block. If nil, a new uuid is automatically
   assigned to the block.
   - Throws:
   `BlocklyError`: Occurs if the block builder for the given name could not be found or if the
   block builder is missing any required pieces.
   - Returns: A new `Block`.
   */
  public func makeBlock(name: String, shadow: Bool, uuid: String? = nil) throws -> Block {
    guard let blockBuilder = _blockBuilders[name] else {
      throw BlocklyError(.illegalArgument,
                         "No block named '\(name)' has been added to this block factory.")
    }
    return try blockBuilder.makeBlock(shadow: shadow, uuid: uuid)
  }

  // MARK: - Internal

  /**
   Creates a new instance of a block with the given name, adds it to a specific workspace, and
   returns it.

   - Parameter name: The name of the block to obtain.
   - Parameter workspace: The workspace that should own the new block.
   - Throws:
   `BlocklyError`: Occurs if the block builder is missing any required pieces.
   - Returns: A new block if the name is known, nil otherwise.
   */
  internal func addBlock(name: String, toWorkspace workspace: Workspace) throws -> Block? {
    guard let block = try? makeBlock(name: name) else {
      return nil
    }
    try workspace.addBlockTree(block)
    return block
  }
}
