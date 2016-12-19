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
 Factory for instantiating new `Block` instances by name.

 Block definitions can be loaded into the factory from:
 - Default files defined by the Blockly library
 - Custom JSON files
 */
@objc(BKYBlockFactory)
public class BlockFactory : NSObject {

  internal var _blockBuilders = Dictionary<String, BlockBuilder>()

  // MARK: - Public

  /**
   Loads blocks from a list of default files defined by the Blockly library. All default mutators
   for those loaded blocks are automatically associated with them as well.

   - parameter defaultFiles: The list of default block definition files that should be loaded.
   - note: This method will overwrite any existing block definitions that contain the same name.
   */
  public func load(fromDefaultFiles defaultFiles: BlockJSONFile) {
    let bundle = Bundle(for: type(of: self))

    do {
      try load(fromJSONPaths: defaultFiles.fileLocations, bundle: bundle)
    } catch let error {
      bky_assertionFailure("Could not load default block definition files in library bundle: " +
        "\(defaultFiles.fileLocations).\nError: \(error)")
    }

    do {
      try setBlockMutators(defaultFiles.blockMutators)
    } catch let error {
      bky_assertionFailure("Could not load mutators of block definition files in library bundle: " +
        "\(defaultFiles.fileLocations).\nError: \(error)")
    }
  }

  /**
   Loads blocks from a list of JSON files.

   - note: This method will overwrite any existing block definitions that contain the same name.
   - parameter jsonPaths: List of paths to files containing blocks in JSON.
   - parameter bundle: The bundle containing the JSON paths. If `nil` is specified,
   `NSBundle.mainBundle()` is used by default.
   - throws:
   `BlocklyError`: Thrown if a JSON file could not be found or read, or if the JSON contains
   invalid block definition(s).
   */
  public func load(fromJSONPaths jsonPaths: [String], bundle: Bundle? = nil) throws {
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
   Sets mutators for any loaded block builders, using a dictionary mapping block names to mutators.

   - parameter blockMutators: Dictionary mapping block names to `Mutator` instances.
   - throws:
   `BlocklyError`: Thrown if a block builder could not be found for a given block name.
   */
  public func setBlockMutators(_ blockMutators: [String: Mutator]) throws {
    var errors = [String]()

    for mapping in blockMutators {
      let blockName = mapping.key
      let mutator = mapping.value

      if let blockBuilder = _blockBuilders[blockName] {
        blockBuilder.mutator = mutator
      } else {
        errors.append("\(#function): Could not locate block named '\(blockName)'.")
      }
    }

    if !errors.isEmpty {
      throw BlocklyError(.illegalArgument, errors.joined(separator: "\n"))
    }
  }

  /**
   Creates and returns a new `Block` with the given name.

   - parameter name: The name of the block to build.
   - throws:
   `BlocklyError`: Occurs if the block builder for the given name could not be found or if the
   block builder is missing any required pieces.
   - returns: A new `Block`.
   */
  public func makeBlock(name: String) throws -> Block {
    return try makeBlock(name: name, shadow: false, uuid: nil)
  }

  /**
   Creates and returns a new `Block` with the given name.

   - parameter name: The name of the block to build.
   - parameter shadow: Specifies whether the resulting block should be a shadow block (`true`) or a
   regular block (`false`).
   - parameter uuid: [Optional] The uuid to assign the block. If nil, a new uuid is automatically
   assigned to the block.
   - throws:
   `BlocklyError`: Occurs if the block builder for the given name could not be found or if the
   block builder is missing any required pieces.
   - returns: A new `Block`.
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

   - parameter name: The name of the block to obtain.
   - parameter workspace: The workspace that should own the new block.
   - throws:
   `BlocklyError`: Occurs if the block builder is missing any required pieces.
   - returns: A new block if the name is known, nil otherwise.
   */
  internal func addBlock(name: String, toWorkspace workspace: Workspace) throws -> Block? {
    guard let block = try? makeBlock(name: name) else {
      return nil
    }
    try workspace.addBlockTree(block)
    return block
  }
}
