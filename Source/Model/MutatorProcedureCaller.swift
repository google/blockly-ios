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
 A mutator for dynamically modifying the properties of a "procedure" caller block.
 */
@objc(BKYMutatorProcedureCaller)
public class MutatorProcedureCaller: NSObject {
  // MARK: - Properties

  /// The target block that will be mutated
  public weak var block: Block?

  /// The associated layout of the mutator
  public weak var layout: MutatorLayout?

  /// The name of the procedure
  public var procedureName = ""

  /// The parameters of the procedure
  public var parameters = [String]()
}

extension MutatorProcedureCaller: Mutator {
  // MARK: - Mutator Implementation

  public func mutateBlock() throws {
    guard let block = self.block else {
      return
    }

    // Update name label
    if let field = block.firstField(withName: "NAME") as? FieldLabel {
      field.text = procedureName + (!parameters.isEmpty ? " with:" : "")
    }

    // Update parameters
    var i = 0
    for parameter in parameters {
      let inputName = "ARG\(i)"
      if let input = block.firstInput(withName: inputName) {
        // Update existing parameter
        (input.fields[0] as? FieldLabel)?.text = parameter
      } else {
        // Create new input parameter
        let parameterBuilder = InputBuilder(type: .value, name: inputName)
        parameterBuilder.alignment = .right
        parameterBuilder.appendField(FieldLabel(name: "ARGNAME\(i)", text: parameter))
        block.appendInput(parameterBuilder.makeInput())
      }

      i += 1
    }

    // Delete extra parameters
    while let input = block.firstInput(withName: "ARG\(i)") {
      try block.removeInput(input)
      i += 1
    }
  }

  public func toXMLElement() -> AEXMLElement {
    let xml = AEXMLElement(name: "mutation", value: nil, attributes: [:])
    xml.attributes["name"] = procedureName

    for parameter in parameters {
      xml.addChild(name: "arg", value: nil, attributes: [
        "name": parameter
      ])
    }

    return xml
  }

  public func update(fromXML xml: AEXMLElement) {
    let mutationXML = xml["mutation"]

    procedureName = mutationXML.attributes["name"] ?? ""

    parameters.removeAll()
    for parameterXML in (mutationXML["arg"].all ?? []) {
      if let parameter = parameterXML.attributes["name"] {
        parameters.append(parameter)
      }
    }
  }

  public func copyMutator() -> Mutator {
    let mutator = MutatorProcedureCaller()
    mutator.procedureName = procedureName
    mutator.parameters = parameters
    return mutator
  }

  /**
   Returns a list of inputs that have been created by this mutator on `self.block`, sorted in
   ascending order of their index within `self.block.inputs`.
   */
  public func sortedMutatorInputs() -> [Input] {
    guard let block = self.block else {
      return []
    }

    var inputs = [Input]()

    // Add parameter inputs
    var i = 0
    while let input = block.firstInput(withName: "ARG\(i)") {
      inputs.append(input)
      i += 1
    }

    return inputs
  }
}
