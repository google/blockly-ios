/*
* Copyright 2015 Google Inc. All Rights Reserved.
* Licensed under the Apache License, Version 2.0 (the "License")
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

class ConnectionTest: XCTestCase {

  // MARK: - Properties

  var allBlocks = [Block]()
  // Test connections
  var input: Connection!
  var output: Connection!
  var next: Connection!
  var previous: Connection!
  var shadowInput: Connection!
  var shadowNext: Connection!
  var shadowOutput: Connection!
  var shadowPrevious: Connection!

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    input = createConnection(.inputValue, shadow: false)
    output = createConnection(.outputValue, shadow: false)
    next = createConnection(.nextStatement, shadow: false)
    previous = createConnection(.previousStatement, shadow: false)
    shadowInput = createConnection(.inputValue, shadow: true)
    shadowOutput = createConnection(.outputValue, shadow: true)
    shadowNext = createConnection(.nextStatement, shadow: true)
    shadowPrevious = createConnection(.previousStatement, shadow: true)
  }

  // MARK: - Tests

  func testConnectInputOutput() {
    XCTAssertFalse(input.connected)
    XCTAssertFalse(output.connected)

    BKYAssertDoesNotThrow { try self.input.connectTo(self.output) }

    XCTAssertTrue(input.connected)
    XCTAssertTrue(output.connected)
    XCTAssertEqual(output, input.targetConnection)
    XCTAssertEqual(input, output.targetConnection)
  }

  func testConnect_OutputInput() {
    XCTAssertFalse(input.connected)
    XCTAssertFalse(output.connected)

    BKYAssertDoesNotThrow { try self.output.connectTo(self.input) }

    XCTAssertTrue(input.connected)
    XCTAssertTrue(output.connected)
    XCTAssertEqual(output, input.targetConnection)
    XCTAssertEqual(input, output.targetConnection)
  }

  func testConnect_PreviousNext() {
    XCTAssertFalse(previous.connected)
    XCTAssertFalse(next.connected)

    BKYAssertDoesNotThrow { try self.previous.connectTo(self.next) }

    XCTAssertTrue(previous.connected)
    XCTAssertTrue(next.connected)
    XCTAssertEqual(next, previous.targetConnection)
    XCTAssertEqual(previous, next.targetConnection)
  }

  func testConnect_NextPrevious() {
    XCTAssertFalse(previous.connected)
    XCTAssertFalse(next.connected)

    BKYAssertDoesNotThrow { try self.next.connectTo(self.previous) }

    XCTAssertTrue(previous.connected)
    XCTAssertTrue(next.connected)
    XCTAssertEqual(next, previous.targetConnection)
    XCTAssertEqual(previous, next.targetConnection)
  }

  func testConnectShadow_InputShadowOutput() {
    XCTAssertFalse(input.shadowConnected)
    XCTAssertFalse(shadowOutput.shadowConnected)

    BKYAssertDoesNotThrow { try self.input.connectShadowTo(self.shadowOutput) }

    XCTAssertTrue(input.shadowConnected)
    XCTAssertTrue(shadowOutput.shadowConnected)
    XCTAssertEqual(shadowOutput, input.shadowConnection)
    XCTAssertEqual(input, shadowOutput.shadowConnection)
  }

  func testConnectShadow_ShadowOutputToInput() {
    XCTAssertFalse(input.shadowConnected)
    XCTAssertFalse(shadowOutput.shadowConnected)

    BKYAssertDoesNotThrow { try self.shadowOutput.connectShadowTo(self.input) }

    XCTAssertTrue(input.shadowConnected)
    XCTAssertTrue(shadowOutput.shadowConnected)
    XCTAssertEqual(shadowOutput, input.shadowConnection)
    XCTAssertEqual(input, shadowOutput.shadowConnection)
  }

  func testConnectShadow_ShadowNextShadowPrevious() {
    XCTAssertFalse(shadowNext.shadowConnected)
    XCTAssertFalse(shadowPrevious.shadowConnected)

    BKYAssertDoesNotThrow { try self.shadowNext.connectShadowTo(self.shadowPrevious) }

    XCTAssertTrue(shadowNext.shadowConnected)
    XCTAssertTrue(shadowPrevious.shadowConnected)
    XCTAssertEqual(shadowPrevious, shadowNext.shadowConnection)
    XCTAssertEqual(shadowNext, shadowPrevious.shadowConnection)
  }

  func testConnectShadow_ShadowPreviousShadowNext() {
    XCTAssertFalse(shadowNext.shadowConnected)
    XCTAssertFalse(shadowPrevious.shadowConnected)

    BKYAssertDoesNotThrow { try self.shadowPrevious.connectShadowTo(self.shadowNext) }

    XCTAssertTrue(shadowNext.shadowConnected)
    XCTAssertTrue(shadowPrevious.shadowConnected)
    XCTAssertEqual(shadowPrevious, shadowNext.shadowConnection)
    XCTAssertEqual(shadowNext, shadowPrevious.shadowConnection)
  }

  func testConnect_shadowFailures() {
    // Shadows hit the same checks as normal blocks.
    // Do light verification to guard against that changing
    let shadowInput2 = createConnection(.inputValue, shadow: true)

    BKYAssertThrow("Connections cannot connect to themselves!", errorType: BlocklyError.self) {
      try self.shadowInput.connectTo(self.shadowInput)
    }

    BKYAssertThrow("Input cannot connect to input!", errorType: BlocklyError.self) {
      try self.input.connectTo(self.shadowInput)
    }

    BKYAssertThrow("Input cannot connect to previous!", errorType: BlocklyError.self) {
      try self.input.connectTo(self.shadowPrevious)
    }

    BKYAssertThrow("Input cannot connect to input!", errorType: BlocklyError.self) {
      try self.shadowInput.connectTo(shadowInput2)
    }

    BKYAssertThrow("Input cannot connect to next!", errorType: BlocklyError.self) {
      try self.shadowInput.connectTo(self.shadowNext)
    }

    BKYAssertThrow("Input cannot connect to previous!", errorType: BlocklyError.self) {
      try self.shadowInput.connectTo(self.shadowPrevious)
    }
  }

  func testDisconnect_InputOutput() {
    BKYAssertDoesNotThrow { try self.input.connectTo(self.output) }

    XCTAssertTrue(input.connected)
    XCTAssertTrue(output.connected)

    BKYAssertDoesNotThrow { self.input.disconnect() }

    XCTAssertNil(input.targetConnection)
    XCTAssertNil(output.targetConnection)
    XCTAssertFalse(input.connected)
    XCTAssertFalse(output.connected)
  }

  func testDisconnectShadow_NextShadowPrevious() {
    BKYAssertDoesNotThrow { try self.next.connectShadowTo(self.shadowPrevious) }

    XCTAssertTrue(next.shadowConnected)
    XCTAssertTrue(shadowPrevious.shadowConnected)

    BKYAssertDoesNotThrow { self.shadowPrevious.disconnectShadow() }

    XCTAssertFalse(next.shadowConnected)
    XCTAssertFalse(shadowPrevious.shadowConnected)
  }

  func testCanConnectWithReasonTo_Valid() {
    XCTAssertEqual(Connection.CheckResult.CanConnect, previous.canConnectWithReasonTo(next))
    XCTAssertEqual(Connection.CheckResult.CanConnect, next.canConnectWithReasonTo(previous))
    XCTAssertEqual(Connection.CheckResult.CanConnect, output.canConnectWithReasonTo(input))
    XCTAssertEqual(Connection.CheckResult.CanConnect, input.canConnectWithReasonTo(output))
  }

  func testCanConnectWithReasonTo_InvalidNull() {
    XCTAssertEqual(Connection.CheckResult.ReasonTargetNull, output.canConnectWithReasonTo(nil))
  }

  func testCanConnectWithReasonTo_InvalidSameBlock() {
    let connection1 = createConnection(.inputValue)
    let connection2 = createConnection(.outputValue)
    connection2.sourceBlock = connection1.sourceBlock
    XCTAssertEqual(Connection.CheckResult.ReasonSelfConnection,
      connection1.canConnectWithReasonTo(connection2))
  }

  func testCanConnectWithReasonTo_InvalidWrongTypes() {
    let connection1 = createConnection(.outputValue)
    let connection2 = createConnection(.outputValue)
    XCTAssertEqual(Connection.CheckResult.ReasonWrongType,
      connection1.canConnectWithReasonTo(connection2))
  }

  func testCanConnectWithReasonTo_InvalidAlreadyConnected() {
    BKYAssertDoesNotThrow { try self.output.connectTo(self.input) }
    let output2 = createConnection(.outputValue)
    XCTAssertEqual(Connection.CheckResult.ReasonMustDisconnect,
      input.canConnectWithReasonTo(output2))
  }

  func testCanConnectWithReasonTo_InvalidTypeChecks() {
    input.typeChecks = ["string"]
    output.typeChecks = ["bool"]
    XCTAssertEqual(
      Connection.CheckResult.ReasonTypeChecksFailed, input.canConnectWithReasonTo(output))
  }

  func testCanConnectWithReasonTo_InvalidShadowBlockForTarget() {
    XCTAssertEqual(Connection.CheckResult.ReasonCannotSetShadowForTarget,
                   next.canConnectWithReasonTo(shadowPrevious))
    XCTAssertEqual(Connection.CheckResult.ReasonCannotSetShadowForTarget,
                   shadowPrevious.canConnectWithReasonTo(next))
    XCTAssertEqual(Connection.CheckResult.ReasonCannotSetShadowForTarget,
                   shadowOutput.canConnectWithReasonTo(input))
    XCTAssertEqual(Connection.CheckResult.ReasonCannotSetShadowForTarget,
                   input.canConnectWithReasonTo(shadowOutput))
  }

  func testCanConnectWithReasonTo_InvalidSourceBlockIsNull() {
    next.sourceBlock = nil
    XCTAssertEqual(Connection.CheckResult.ReasonSourceBlockNull,
                   next.canConnectWithReasonTo(previous))
    output.sourceBlock = nil
    XCTAssertEqual(Connection.CheckResult.ReasonSourceBlockNull,
                   output.canConnectWithReasonTo(input))
  }

  func testCanConnectShadowWithReasonTo_Valid() {
    XCTAssertEqual(Connection.CheckResult.CanConnect,
                   input.canConnectShadowWithReasonTo(shadowOutput))
    XCTAssertEqual(Connection.CheckResult.CanConnect,
                   shadowInput.canConnectShadowWithReasonTo(shadowOutput))
    XCTAssertEqual(Connection.CheckResult.CanConnect,
                   next.canConnectShadowWithReasonTo(shadowPrevious))
    XCTAssertEqual(Connection.CheckResult.CanConnect,
                   shadowNext.canConnectShadowWithReasonTo(shadowPrevious))

    // Verify it can still connect after a non-shadow has been connected
    BKYAssertDoesNotThrow { try self.input.connectTo(self.output) }
    XCTAssertEqual(
      Connection.CheckResult.CanConnect, input.canConnectShadowWithReasonTo(shadowOutput))

    // Verify a normal connection can be made after a shadow connection
    BKYAssertDoesNotThrow { try self.next.connectShadowTo(self.shadowPrevious) }
    XCTAssertEqual(
      Connection.CheckResult.CanConnect, next.canConnectWithReasonTo(previous))
  }

  func testCanConnectShadowWithReasonTo_InvalidNull() {
    XCTAssertEqual(
      Connection.CheckResult.ReasonShadowNull, input.canConnectShadowWithReasonTo(nil))
  }

  func testCanConnectShadowWithReasonTo_InvalidSameBlock() {
    let connection1 = createConnection(.inputValue)
    let connection2 = createConnection(.outputValue, shadow: true)
    connection2.sourceBlock = connection1.sourceBlock
    let canConnectReason = connection1.canConnectShadowWithReasonTo(connection2)
    XCTAssertTrue(canConnectReason.intersectsWith(Connection.CheckResult.ReasonSelfConnection))
  }

  func testCanConnectShadowWithReasonTo_InvalidWrongTypes() {
    let connection1 = createConnection(.outputValue, shadow: true)
    let connection2 = createConnection(.outputValue, shadow: true)
    XCTAssertEqual(Connection.CheckResult.ReasonWrongType,
                   connection1.canConnectShadowWithReasonTo(connection2))
  }

  func testCanConnectShadowWithReasonTo_InvalidAlreadyConnected() {
    let shadowOutput2 = createConnection(.outputValue, shadow: true)
    BKYAssertDoesNotThrow { try self.input.connectShadowTo(self.shadowOutput) }
    XCTAssertEqual(Connection.CheckResult.ReasonMustDisconnect,
                   input.canConnectShadowWithReasonTo(shadowOutput2))
  }

  func testCanConnectShadowWithReasonTo_InvalidTypeChecks() {
    next.typeChecks = ["string"]
    shadowPrevious.typeChecks = ["bool"]
    XCTAssertEqual(Connection.CheckResult.ReasonTypeChecksFailed,
                   next.canConnectShadowWithReasonTo(shadowPrevious))
  }

  func testCanConnectShadowWithReasonTo_InvalidInferiorBlockShadowMismatch() {
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   next.canConnectShadowWithReasonTo(previous))
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   previous.canConnectShadowWithReasonTo(next))
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   shadowNext.canConnectShadowWithReasonTo(previous))
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   previous.canConnectShadowWithReasonTo(shadowNext))

    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   output.canConnectShadowWithReasonTo(input))
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   input.canConnectShadowWithReasonTo(output))
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   output.canConnectShadowWithReasonTo(shadowInput))
    XCTAssertEqual(Connection.CheckResult.ReasonInferiorBlockShadowMismatch,
                   shadowInput.canConnectShadowWithReasonTo(output))
  }

  func testCanConnectShadowWithReasonTo_InvalidSourceBlockIsNull() {
    next.sourceBlock = nil
    XCTAssertEqual(Connection.CheckResult.ReasonSourceBlockNull,
                   next.canConnectShadowWithReasonTo(shadowPrevious))
    shadowOutput.sourceBlock = nil
    XCTAssertEqual(Connection.CheckResult.ReasonSourceBlockNull,
                   input.canConnectShadowWithReasonTo(shadowOutput))
  }

  func testDistanceFromConnection() {
    let connection1 = createConnection(.nextStatement, 0, 0)
    let connection2 = createConnection(.inputValue, 0, 0)
    XCTAssertEqual(0, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePoint(x: 5.20403, y: 0))
    XCTAssertEqual(5.20403, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePoint(x: 0, y: 9.234))
    XCTAssertEqual(9.234, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePoint(x: 3, y: 4))
    XCTAssertEqual(5, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePoint(x: -2, y: 0))
    XCTAssertEqual(2, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePoint(x: 0, y: -1.5))
    XCTAssertEqual(1.5, connection1.distanceFromConnection(connection2))

    connection1.moveToPosition(WorkspacePoint(x: 10, y: 10))
    connection2.moveToPosition(WorkspacePoint(x: 310, y: -390))
    XCTAssertEqual(500, connection1.distanceFromConnection(connection2))
  }

  func testTypeChecksMatchWithConnection() {
    let connection1 = createConnection(.previousStatement)
    let connection2 = createConnection(.nextStatement)

    connection1.typeChecks = nil
    connection2.typeChecks = nil
    XCTAssertTrue(connection1.typeChecksMatchWithConnection(connection2))

    connection1.typeChecks = nil
    connection2.typeChecks = []
    XCTAssertTrue(connection1.typeChecksMatchWithConnection(connection2))

    connection1.typeChecks = []
    connection2.typeChecks = []
    XCTAssertFalse(connection1.typeChecksMatchWithConnection(connection2))

    connection1.typeChecks = [""]
    connection2.typeChecks = [""]
    XCTAssertTrue(connection1.typeChecksMatchWithConnection(connection2))

    connection1.typeChecks = nil
    connection2.typeChecks = ["string"]
    XCTAssertTrue(connection1.typeChecksMatchWithConnection(connection2))

    connection1.typeChecks = ["int", "string"]
    connection2.typeChecks = ["string"]
    XCTAssertTrue(connection1.typeChecksMatchWithConnection(connection2))

    connection1.typeChecks = ["String"]
    connection2.typeChecks = ["string"]
    XCTAssertFalse(connection1.typeChecksMatchWithConnection(connection2))
  }

  // MARK: - Helper methods

  fileprivate func createConnection(
    _ type: Connection.ConnectionType, _ x: CGFloat = 0, _ y: CGFloat = 0, shadow: Bool = false)
    -> Connection
  {
    let block = try! BlockBuilder(name: "test").makeBlock(shadow: shadow)
    allBlocks.append(block) // Keep a reference of the block so it doesn't get dealloced

    let connection = Connection(type: type, sourceInput: nil)
    connection.moveToPosition(WorkspacePoint(x: x, y: y))
    connection.sourceBlock = block
    return connection
  }
}
