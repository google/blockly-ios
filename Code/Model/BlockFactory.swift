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
  public unowned let workspace: Workspace

  internal var blocks = [String : Block]()

  // MARK: - Initializers

  /**
  Creates a BlockFactory with an initial set of blocks loaded from a json file.

  - Parameter jsonPath: Optional path to a file containing blocks in JSON.
  */
  public init(jsonPath: String?, workspace: Workspace) throws {
    self.workspace = workspace
    super.init()
    if jsonPath == nil {
      return
    }
    let bundle = NSBundle(forClass: self.dynamicType.self)
    let path = bundle.pathForResource(jsonPath, ofType: "json")
    let jsonString = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
    let json = try NSJSONSerialization.bky_JSONArrayFromString(jsonString)
    for blockJson in json {
      let block = try Block.blockFromJSON(blockJson as! [String : AnyObject], workspace: workspace)
      blocks[block.identifier] = block
      bky_debugPrint("Added block with name " + block.identifier)
    }
  }

  // MARK: - Public

  /**
  Create a new instance of a block with the given name.

  - Parameter blockName: The name of the block to obtain.
  - Returns: A new block if the name is known, nil otherwise.
  */
  public func obtain(blockName: String) -> Block? {
    if let block = blocks[blockName] {
      bky_debugPrint("Found block " + block.identifier)
      return Block.Builder(block: block, workspace: workspace).build()
    } else {
      return nil
    }
  }
}
