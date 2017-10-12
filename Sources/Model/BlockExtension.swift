/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

// MARK: - BlockExtension Protocol

/**
 Protocol for extension code that can be executed on a `Block` during its initialization.
 */
@objc(BKYBlockExtension)
public protocol BlockExtension: class {
  // MARK: - Extension Code

  /**
   Runs extension code for a given block.

   - parameter block: The block that is the target of the extension code.
   - throws:
   `BlocklyError`: Thrown if an error occurs while running the extension code.
   */
  func run(block: Block) throws
}

// MARK: - BlockExtensionClosure

/**
 Wraps extension code in a closure so it can be executed on a `Block` during its initialization.
 */
@objc(BKYBlockExtensionClosure)
@objcMembers public final class BlockExtensionClosure: NSObject, BlockExtension {
  // MARK: - Properties

  /// The closure that is executed by this extension during `Block` initialization.
  private var _closure: (Block) -> Void

  // MARK: - Initializers

  /**
   Creates a block extension.

   - parameter closure: Code that should be run for a `Block` during its initialization.
   */
  public init(_ closure: @escaping (Block) -> Void) {
    _closure = closure
  }

  // MARK: - Run

  /**
   Runs extension code on a given block.

   - parameter block: The block that is used for the extension code closure.
   */
  public func run(block: Block) throws {
    _closure(block)
  }
}
