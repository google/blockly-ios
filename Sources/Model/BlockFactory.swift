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

 Block builders can be loaded into the factory by:

 - Loading default files containing JSON block definitions. The contents of these files are
 predefined by the Blockly library.
 - Loading custom files containing JSON block definitions.
 - Manually creating a `BlockBuilder` for a specific block name and assigning it to the factory.
 */
@objc(BKYBlockFactory)
@objcMembers public class BlockFactory : NSObject {

  // MARK: - Properties

  /// Dictionary of `BlockExtension` objects indexed by their extension name
  public private(set) var blockExtensions = [String: BlockExtension]()

  /// Dictionary of `Mutator` objects indexed by their mutator name
  public private(set) var mutators = [String: Mutator]()

  /// Dictionary of `BlockBuilder` objects indexed by their block name
  private var blockBuilders = Dictionary<String, BlockBuilder>()

  // MARK: - Public

  /**
   Loads block builders from a list of default files containing JSON block definitions. The
   contents of these files are predefined by the Blockly library.

   - note: This method will overwrite any existing block builders that contain the same name.
   - parameter defaultFiles: The list of default block definition files that should be loaded.
   */
  public func load(fromDefaultFiles defaultFiles: BlockJSONFile) {
    let bundle = Bundle(for: BlockFactory.self)

    updateMutators(defaultFiles.mutators)
    updateBlockExtensions(defaultFiles.blockExtensions)

    do {
      try load(fromJSONPaths: defaultFiles.fileLocations, bundle: bundle)
    } catch let error {
      bky_assertionFailure("Could not load default block definition files in library bundle: " +
        "\(defaultFiles.fileLocations).\nError: \(error)")
    }
  }

  /**
   Loads block builders from a list of files containing JSON block definitions.

   - note: This method will overwrite any existing block builders that contain the same name.
   - parameter jsonPaths: List of paths to files containing JSON block definitions.
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
        let blockBuilder = try Block.makeBuilder(
          json: blockJson as! [String : Any], mutators: mutators, extensions: blockExtensions)

        // Ensure the builder is valid
        _ = try blockBuilder.makeBlock()

        // Save the block builder
        setBlockBuilder(blockBuilder, forName: blockBuilder.name)
      }
    }
  }

  /**
   Sets the block builder to use when making new blocks of a given name.

   - note: This method automatically sets `blockBuilder.name` to match the given `name`.
   - parameter blockBuilder: The `BlockBuilder` to use.
   - parameter name: The block name to associate with this block builder.
   */
  public func setBlockBuilder(_ blockBuilder: BlockBuilder, forName name: String) {
    blockBuilder.name = name
    blockBuilders[name] = blockBuilder
  }

  /**
   Returns the block builder that is being used for given block name.

   - parameter name: The block name to search for the block builder.
   - returns: The `BlockBuilder` matching the given `name` or `nil` if no block builder could be
   found.
   */
  public func blockBuilder(forName name: String) -> BlockBuilder? {
    return blockBuilders[name]
  }

  /**
   Updates `self.mutators` from a dictionary of mutators. If a mutator already exists in
   `self.mutators` for a given name, that value is overwritten by the one
   supplied by `mutators`. These mutators are associated with block builders when they are
   loaded from JSON files.

   - parameter mutators: Dictionary mapping `Mutator` objects to their mutator name.
   */
  public func updateMutators(_ mutators: [String: Mutator]) {
    for (name, mutator) in mutators {
      self.mutators[name] = mutator
    }
  }

  /**
   Updates `self.blockExtensions` from a dictionary of given block extensions. If an extension
   already exists in `self.blockExtensions` for a given name, that value is overwritten by the one
   supplied by `extensions`. These extensions are associated with block builders when they are
   loaded from JSON files.

   - parameter extensions: Dictionary mapping `BlockExtension` objects to their extension name.
   */
  public func updateBlockExtensions(_ blockExtensions: [String: BlockExtension]) {
    for (name, blockExtension) in blockExtensions {
      self.blockExtensions[name] = blockExtension
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
    guard let blockBuilder = blockBuilders[name] else {
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
