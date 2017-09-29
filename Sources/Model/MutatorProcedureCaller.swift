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
@objcMembers public class MutatorProcedureCaller: NSObject {
  // MARK: - Properties

  /// The target block that will be mutated
  public weak var block: Block?

  /// The associated layout of the mutator
  public weak var layout: MutatorLayout?

  /// The name of the procedure
  public var procedureName = ""

  /// The parameters of the procedure
  public var parameters = [ProcedureParameter]()

  /// The actual name that's been applied to the procedure
  fileprivate var appliedProcedureName = ""

  /// The actual parameters that have been added to the procedure caller
  fileprivate var appliedParameters = [ProcedureParameter]()
}

extension MutatorProcedureCaller: Mutator {
  // MARK: - Mutator Implementation

  public func mutateBlock() throws {
    guard let block = self.block else {
      return
    }

    // Update name label
    if let field = block.firstField(withName: "NAME") as? FieldLabel {
      field.text = procedureName
    }

    // Update "with: " field
    if let input = block.firstInput(withName: "TOPROW") {
      let withField = block.firstField(withName: "WITH")
      if parameters.isEmpty,
        let field = withField
      {
        input.removeField(field)
      } else if !parameters.isEmpty && withField == nil {
        let withText = message(forKey: "BKY_PROCEDURES_CALL_BEFORE_PARAMS")
        input.appendField(FieldLabel(name: "WITH", text: withText))
      }
    }

    // Update parameters
    var i = 0
    for parameter in parameters {
      let inputName = "ARG\(i)"
      if let input = block.firstInput(withName: inputName) {
        // Update existing parameter
        (input.fields[0] as? FieldLabel)?.text = parameter.name
      } else {
        // Create new input parameter
        let parameterBuilder = InputBuilder(type: .value, name: inputName)
        parameterBuilder.alignment = .right
        parameterBuilder.appendField(FieldLabel(name: "ARGNAME\(i)", text: parameter.name))
        block.appendInput(parameterBuilder.makeInput())
      }

      i += 1
    }

    // Delete extra parameters
    while let input = block.firstInput(withName: "ARG\(i)") {
      try block.removeInput(input)
      i += 1
    }

    appliedProcedureName = procedureName
    appliedParameters = parameters
  }

  public func toXMLElement() -> AEXMLElement {
    let xml = AEXMLElement(name: "mutation", value: nil, attributes: [:])
    xml.attributes["name"] = appliedProcedureName

    for parameter in appliedParameters {
      xml.addChild(name: "arg", value: nil, attributes: [
        "name": parameter.name,
        "id": parameter.uuid
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
        let uuid = parameterXML.attributes["id"]
        parameters.append(ProcedureParameter(name: parameter, uuid: uuid))
      }
    }
  }

  public func copyMutator() -> Mutator {
    let mutator = MutatorProcedureCaller()
    mutator.procedureName = procedureName
    mutator.parameters = parameters
    mutator.appliedProcedureName = appliedProcedureName
    mutator.appliedParameters = appliedParameters
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

    // Add parameter inputs
    var i = 0
    while let input = block.firstInput(withName: "ARG\(i)") {
      inputs.append(input)
      i += 1
    }

    return inputs
  }
}
