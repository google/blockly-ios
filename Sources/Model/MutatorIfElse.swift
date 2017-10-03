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
 A mutator for dynamically adding "else-if" and "else" statements to an "if" block.
 */
@objc(BKYMutatorIfElse)
@objcMembers public class MutatorIfElse: NSObject {
  // MARK: - Properties

  /// The target block that will be mutated
  public weak var block: Block?

  /// The associated layout of the mutator
  public weak var layout: MutatorLayout?

  /// The number of else-if statements that should be added to the block
  public var elseIfCount = 0 {
    didSet {
      elseIfCount = max(elseIfCount, 0)
    }
  }

  /// Flag determining if an else statement should be added to the block
  public var elseStatement = false

  /// The actual number of else-if statements that have been added to the block
  fileprivate var appliedElseIfCount = 0

  /// Flag determining if the else statement has actually been added to the block
  fileprivate var appliedElseStatement = false
}

extension MutatorIfElse: Mutator {
  // MARK: - Mutator Implementation

  public func mutateBlock() throws {
    guard let block = self.block else {
      return
    }

    if elseIfCount > appliedElseIfCount {
      let appliedElseCount = appliedElseStatement ? 1 : 0

      // Add extra else-if statements
      for count in appliedElseIfCount ..< elseIfCount {
        let i = count + 1 // 1-based indexing
        let ifBuilder = InputBuilder(type: .value, name: "IF\(i)")
        ifBuilder.connectionTypeChecks = ["Boolean"]

        let elseIfText = message(forKey: "BKY_CONTROLS_IF_MSG_ELSEIF")
        ifBuilder.appendField(FieldLabel(name: "ELSEIF", text: elseIfText))

        let doText = message(forKey: "BKY_CONTROLS_IF_MSG_THEN")
        let doBuilder = InputBuilder(type: .statement, name: "DO\(i)")
        doBuilder.appendField(FieldLabel(name: "DO", text: doText))

        // Insert else-if statement before any applied else input (which would be at the very end)
        block.insertInput(ifBuilder.makeInput(), at: (block.inputs.count - appliedElseCount))
        block.insertInput(doBuilder.makeInput(), at: (block.inputs.count - appliedElseCount))
      }
    } else if elseIfCount < appliedElseIfCount {
      // Remove extra else-if statements
      for count in elseIfCount ..< appliedElseIfCount {
        let i = count + 1 // 1-based indexing
        if let ifInput = block.firstInput(withName: "IF\(i)"),
          let doInput = block.firstInput(withName: "DO\(i)")
        {
          try block.removeInput(ifInput)
          try block.removeInput(doInput)
        }
      }
    }
    appliedElseIfCount = elseIfCount

    if elseStatement && !appliedElseStatement {
      // Add else statement
      let elseBuilder = InputBuilder(type: .statement, name: "ELSE")
      let elseText = message(forKey: "BKY_CONTROLS_IF_MSG_ELSE")
      elseBuilder.appendField(FieldLabel(name: "ELSE", text: elseText))

      // Always insert else statement at the very end
      block.appendInput(elseBuilder.makeInput())
    } else if !elseStatement && appliedElseStatement,
      let elseInput = block.firstInput(withName: "ELSE")
    {
      // Remove else statement
      try block.removeInput(elseInput)
    }
    appliedElseStatement = elseStatement
  }

  public func toXMLElement() -> AEXMLElement {
    return AEXMLElement(name: "mutation", value: nil, attributes: [
        "elseif": String(appliedElseIfCount),
        "else": String(appliedElseStatement ? "1" : "0")
      ])
  }

  public func update(fromXML xml: AEXMLElement) {
    let mutationXML = xml["mutation"]
    elseIfCount = Int(mutationXML.attributes["elseif"] ?? "") ?? 0
    elseStatement = (Int(mutationXML.attributes["else"] ?? "") ?? 0) > 0
  }

  public func copyMutator() -> Mutator {
    let mutator = MutatorIfElse()
    mutator.elseIfCount = elseIfCount
    mutator.elseStatement = elseStatement
    mutator.appliedElseIfCount = appliedElseIfCount
    mutator.appliedElseStatement = appliedElseStatement
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

    for count in 0 ..< appliedElseIfCount {
      let i = count + 1 // 1-based indexing
      if let ifInput = block.firstInput(withName: "IF\(i)"),
        let doInput = block.firstInput(withName: "DO\(i)")
      {
        inputs.append(ifInput)
        inputs.append(doInput)
      }
    }

    if let input = block.firstInput(withName: "ELSE"), appliedElseStatement {
      inputs.append(input)
    }

    return inputs
  }
}
