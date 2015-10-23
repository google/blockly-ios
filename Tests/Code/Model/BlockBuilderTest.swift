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

@testable import Blockly
import XCTest

class BlockBuilderTest: XCTestCase {

  func testBuildBlock() {
    let workspace = Workspace(layoutFactory: nil, isFlyout: false)
    let block = buildFrankenBlock(workspace).build()
    validateFrankenblock(block)
  }

  func testBuildFromBlock() {
    let workspace = Workspace(layoutFactory: nil, isFlyout: false)
    let block = buildFrankenBlock(workspace).build()
    let block2 = buildFrankenBlock(workspace).build()
    try! block.nextConnection?.connectTo(block2.previousConnection)
    let block3 = buildFrankenBlock(workspace).build()
    try! block.previousConnection?.connectTo(block3.nextConnection)

    let blockCopy = Block.Builder(block: block, workspace: workspace).build()
    validateFrankenblock(blockCopy)

    // Validate that the block was deep copied
    XCTAssertTrue(block !== blockCopy)
    XCTAssertTrue(block.inputs[0] !== blockCopy.inputs[0])
    XCTAssertTrue(block.inputs[0].fields[0] !== blockCopy.inputs[0].fields[0])

    // Validate that the connections were not copied
    XCTAssertNil(blockCopy.nextConnection?.targetConnection)
    XCTAssertNil(blockCopy.previousConnection?.targetConnection)
    // TODO:(roboerik) validate output and input connections

  }

  internal func validateFrankenblock(block: Block) {
    XCTAssertEqual("frankenblock", block.identifier)
    XCTAssertEqual(3, block.inputs.count)
    XCTAssertEqual(20, block.colourHue)
    XCTAssertEqual("http://www.example.com", block.helpURL)
    XCTAssertEqual("a tooltip", block.tooltip)

    XCTAssertNotNil(block.previousConnection)
    XCTAssertNil(block.previousConnection?.typeChecks)
    XCTAssertEqual(block, block.previousConnection?.sourceBlock)
    XCTAssertNotNil(block.nextConnection)
    XCTAssertEqual(["Boolean", "Number", "Array"], (block.nextConnection?.typeChecks)!)
    XCTAssertEqual(block, block.nextConnection?.sourceBlock)
    XCTAssertNil(block.outputConnection)

    var input = block.inputs[0]
    XCTAssertEqual(Input.InputType.Value, input.type)
    XCTAssertEqual(2, input.fields.count)
    XCTAssertEqual(block, input.sourceBlock)
    XCTAssertEqual(block, input.connection?.sourceBlock)

    let fieldInput = input.fields[0] as? FieldInput
    XCTAssertNotNil(fieldInput)
    XCTAssertEqual("text_input", fieldInput?.name)
    XCTAssertEqual("something", fieldInput?.text)
    XCTAssertNotNil(input.fields[1] as? FieldCheckbox)

    input = block.inputs[1]
    XCTAssertEqual(Input.InputType.Statement, input.type)
    XCTAssertEqual(block, input.sourceBlock)
    XCTAssertEqual(block, input.connection?.sourceBlock)
    XCTAssertEqual(2, input.fields.count)
    XCTAssertNotNil(input.fields[0] as? FieldDropdown)
    XCTAssertNotNil(input.fields[1] as? FieldVariable)

    input = block.inputs[2]
    XCTAssertEqual(Input.InputType.Dummy, input.type)
    XCTAssertEqual(block, input.sourceBlock)
    XCTAssertNil(input.connection) // Dummy inputs have nil connections
    XCTAssertNotNil(input.fields[0] as? FieldAngle)
    XCTAssertNotNil(input.fields[1] as? FieldColour)
    XCTAssertNotNil(input.fields[2] as? FieldImage)
  }

  internal func buildFrankenBlock(workspace: Workspace) -> Block.Builder {
    let bob = Block.Builder(identifier: "frankenblock", workspace: workspace)

    var input = Input(type: Input.InputType.Value, name: "value_input", workspace: workspace)
    var field = FieldInput(name: "text_input", text: "something", workspace: workspace) as Field
    input.appendField(field)
    field = FieldCheckbox(name: "checkbox", checked: true, workspace: workspace)
    input.appendField(field)
    bob.inputs.append(input)

    input = Input(type: Input.InputType.Statement, name:"statement_input", workspace: workspace)
    do {
      field = try FieldDropdown(name: "dropdown",
        displayNames: ["option1", "option2", "option3"],
        values: ["OPTION1", "OPTION2", "OPTION3"],
        workspace: workspace)
    } catch let error as NSError {
      XCTFail("Error: \(error)")
    }
    input.appendField(field)
    field = FieldVariable(name: "variable", variable: "item", workspace: workspace)
    input.appendField(field)
    bob.inputs.append(input)

    input = Input(type: Input.InputType.Dummy, name: "dummy_input", workspace: workspace)
    field = FieldAngle(name: "angle", angle: 90, workspace: workspace)
    input.appendField(field)
    field = FieldColour(name: "colour", colour: UIColor.magentaColor(), workspace: workspace)
    input.appendField(field)
    field = FieldImage(name: "no name",
      imageURL: "https://www.gstatic.com/codesite/ph/images/star_on.gif",
      size: WorkspaceSize(width: 15, height: 20), altText: "*", workspace: workspace)
    input.appendField(field)
    bob.inputs.append(input)

    do {
      try bob.setPreviousConnectionEnabled(true)
      try bob.setNextConnectionEnabled(true, typeChecks: ["Boolean", "Number", "Array"])
    } catch let error as NSError {
      XCTFail("Error: \(error)")
    }
    bob.colourHue = 20
    bob.helpURL = "http://www.example.com"
    bob.tooltip = "a tooltip"
    
    return bob
  }
}
