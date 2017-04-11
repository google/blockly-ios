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

import AEXML
import Foundation

/**
 Defines a protocol for mutating the structure of a `Block`.
 */
public protocol Mutator : class {
  /**
   The block that should be mutated by this mutator.
   */
  weak var block: Block? { get set }

  /**
   The layout associated with this mutator.
   */
  weak var layout: MutatorLayout? { get set }

  /**
   Mutates `self.block` based on this mutator's internal state.

   This mutation is not additive, so any previously applied mutation should not be reflected on
   `self.block`.

   - throws: Throws an error if the block could not be mutated.
   */
  func mutateBlock() throws

  /**
   Returns the XML based on this mutator's internal state, which will be included as a direct child
   of the exported XML for `self.block`.

   - returns: An `AEXMLElement` object representing this mutator's internal state.
   */
  func toXMLElement() -> AEXMLElement

  /**
   Updates this mutator's internal state, using the XML from the block.

   - parameter xml: The XML of the block.
   - note: This method call does not actually mutate the block.
   `mutateBlock()` must be explicitly called after this.
   */
  func update(fromXML xml: AEXMLElement)

  /**
   Returns a copy of this mutator.

   - returns: A new copy of this mutator, but with its `block` property set to `nil`.
   */
  func copyMutator() -> Mutator
}
