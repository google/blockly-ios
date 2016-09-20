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
@objc(BKYLayoutFactory)
public protocol LayoutFactory: class {
  /**
   Builds and returns a `BlockLayout` for a given block and layout engine.

   - Parameter block: The given `Block`
   - Parameter engine: The `LayoutEngine` to associate with the new layout
   - Returns: A new `BlockLayout` instance or nil, if either `workspace.layout` is nil or no
   suitable layout could be found for the block.
   - Throws:
   `BlocklyError`: Thrown if no suitable `BlockLayout` could be found for the `block`.
   */
  func makeBlockLayout(block: Block, engine: LayoutEngine) throws -> BlockLayout

  /**
   Builds and returns a `BlockGroupLayout` for a given layout engine.

   - Parameter engine: The `LayoutEngine` to associate with the new layout.
   - Returns: A new `BlockGroupLayout` instance.
   - Throws:
   `BlocklyError`: Thrown if no suitable `BlockGroupLayout` could be found.
   */
  func makeBlockGroupLayout(engine: LayoutEngine) throws -> BlockGroupLayout

  /**
   Builds and returns an `InputLayout` for a given input and layout engine.

   - Parameter input: The given `Input`
   - Parameter engine: The `LayoutEngine` to associate with the new layout
   - Returns: A new `InputLayout` instance.
   - Throws:
   `BlocklyError`: Thrown if no suitable `InputLayout` could be found for the `input`.
   */
  func makeInputLayout(input: Input, engine: LayoutEngine) throws -> InputLayout

  /**
   Builds and returns a `FieldLayout` for a given field and layout engine, using the
   `FieldLayoutCreator` that was registered via
   `registerLayoutCreatorForFieldType(:, layoutCreator:)`.

    - Parameter field: The given `Field`
    - Parameter engine: The `LayoutEngine` to associate with the new layout
    - Returns: A new `FieldLayout` instance.
    - Throws:
    `BlocklyError`: Thrown if no suitable `FieldLayout` could be found for the `field`.
   */
  func makeFieldLayout(field: Field, engine: LayoutEngine) throws -> FieldLayout
}
