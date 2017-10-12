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

import AEXML
import Foundation

/**
 A mutator for dynamically modifying an "if/return" block (which is to be used exclusively inside
 of a procedure definition block).
 */
@objc(BKYMutatorProcedureIfReturn)
@objcMembers public class MutatorProcedureIfReturn: NSObject {
  // MARK: - Properties

  /// The target block that will be mutated
  public weak var block: Block?

  /// The associated layout of the mutator
  public weak var layout: MutatorLayout?

  /// Flag determining if this block should accept a return input value.
  public var hasReturnValue: Bool = true

  /// Flag determining if this block has actually applied whether it should accept a return input
  /// value.
  fileprivate var appliedHasReturnValue: Bool = true
}

extension MutatorProcedureIfReturn: Mutator {
  // MARK: - Mutator Implementation

  public func mutateBlock() throws {
    guard let block = self.block else {
      return
    }

    let applyHasReturnValue = hasReturnValue && !appliedHasReturnValue
    let applyHasNoReturnValue = !hasReturnValue && appliedHasReturnValue

    if applyHasReturnValue || applyHasNoReturnValue {
      if let input = block.firstInput(withName: "VALUE") {
        try block.removeInput(input)
      }
      let inputBuilder = InputBuilder(type: applyHasReturnValue ? .value : .dummy, name: "VALUE")
      inputBuilder.appendField(FieldLabel(name: "", text: "return"))
      block.appendInput(inputBuilder.makeInput())
    }
    appliedHasReturnValue = hasReturnValue
  }

  public func toXMLElement() -> AEXMLElement {
    let xml = AEXMLElement(name: "mutation", value: nil, attributes: [:])
    xml.attributes["value"] = appliedHasReturnValue ? "1" : "0"
    return xml
  }

  public func update(fromXML xml: AEXMLElement) {
    let mutationXML = xml["mutation"]
    hasReturnValue = (Int(mutationXML.attributes["value"] ?? "") ?? 0) == 1
  }

  public func copyMutator() -> Mutator {
    let mutator = MutatorProcedureIfReturn()
    mutator.hasReturnValue = hasReturnValue
    mutator.appliedHasReturnValue = appliedHasReturnValue
    return mutator
  }

  /**
   Returns a list of inputs that have been created by this mutator on `self.block`, sorted in
   ascending order of their index within `self.block.inputs`.

   - returns: A sorted list of inputs created by this mutator on `self.block`.
   */
  public func sortedMutatorInputs() -> [Input] {
    guard let block = self.block else {
      return []
    }

    var inputs = [Input]()

    if let input = block.firstInput(withName: "VALUE") {
      inputs.append(input)
    }

    return inputs
  }
}


