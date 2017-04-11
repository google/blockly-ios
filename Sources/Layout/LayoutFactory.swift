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
 Protocol defining a factory responsible for returning new `Layout` instances.
 */
public protocol LayoutFactory: class {
  /**
   Builds and returns a `BlockLayout` for a given block and layout engine.

   - parameter block: The given `Block`
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `BlockLayout` instance or nil, if either `workspace.layout` is nil or no
   suitable layout could be found for the block.
   - throws:
   `BlocklyError`: Thrown if no suitable `BlockLayout` could be found for the `block`.
   */
  func makeBlockLayout(block: Block, engine: LayoutEngine) throws -> BlockLayout

  /**
   Builds and returns a `BlockGroupLayout` for a given layout engine.

   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - returns: A new `BlockGroupLayout` instance.
   - throws:
   `BlocklyError`: Thrown if no suitable `BlockGroupLayout` could be found.
   */
  func makeBlockGroupLayout(engine: LayoutEngine) throws -> BlockGroupLayout

  /**
   Builds and returns an `InputLayout` for a given input and layout engine.

   - parameter input: The given `Input`
   - parameter engine: The `LayoutEngine` to associate with the new layout
   - returns: A new `InputLayout` instance.
   - throws:
   `BlocklyError`: Thrown if no suitable `InputLayout` could be found for the `input`.
   */
  func makeInputLayout(input: Input, engine: LayoutEngine) throws -> InputLayout

  /**
   Builds and returns a `FieldLayout` for a given field and layout engine.

    - parameter field: The given `Field`
    - parameter engine: The `LayoutEngine` to associate with the new layout
    - returns: A new `FieldLayout` instance.
    - throws:
    `BlocklyError`: Thrown if no suitable `FieldLayout` could be found for the `field`.
   */
  func makeFieldLayout(field: Field, engine: LayoutEngine) throws -> FieldLayout

  /**
   Builds and returns a `MutatorLayout` for a given mutator and layout engine.

   - parameter mutator: The given `Mutator`
   - parameter engine: The `LayoutEngine` to associate with the new layout
   - returns: A new `MutatorLayout` instance.
   - throws:
   `BlocklyError`: Thrown if no suitable `MutatorLayout` could be found for the `mutator`.
   */
  func makeMutatorLayout(mutator: Mutator, engine: LayoutEngine) throws -> MutatorLayout
}
