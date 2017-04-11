/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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
import Blockly
import AEXML

/**
 Dummy mutator for testing.
 */
internal class DummyMutator: Mutator {
  weak var block: Block?
  weak var layout: MutatorLayout?

  // An ID property which can be used for testing
  public var id = ""

  // Optional closure that is executed when `self.mutateBlock()` is called, which can be used for
  // testing.
  public var mutationClosure: ((DummyMutator) -> Void)? = nil

  func mutateBlock() {
    // Call optional mutation closure
    mutationClosure?(self)
  }

  func toXMLElement() -> AEXMLElement {
    let xml = AEXMLElement(name:"mutation")
    xml.attributes["id"] = id
    return xml
  }

  func update(fromXML xml: AEXMLElement) {
    let mutationXML = xml["mutation"]
    if let id = mutationXML.attributes["id"] {
      self.id = id
    }
  }

  func copyMutator() -> Mutator {
    let mutator = DummyMutator()
    mutator.id = id
    mutator.mutationClosure = mutationClosure
    return mutator
  }
}
