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
    input = createConnection(.InputValue, shadow: false)
    output = createConnection(.OutputValue, shadow: false)
    next = createConnection(.NextStatement, shadow: false)
    previous = createConnection(.PreviousStatement, shadow: false)
    shadowInput = createConnection(.InputValue, shadow: true)
    shadowOutput = createConnection(.OutputValue, shadow: true)
    shadowNext = createConnection(.NextStatement, shadow: true)
    shadowPrevious = createConnection(.PreviousStatement, shadow: true)
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
    let shadowInput2 = createConnection(.InputValue, shadow: true)

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
    XCTAssertEqual(Connection.CheckResultType.CanConnect, previous.canConnectWithReasonTo(next))
    XCTAssertEqual(Connection.CheckResultType.CanConnect, next.canConnectWithReasonTo(previous))
    XCTAssertEqual(Connection.CheckResultType.CanConnect, output.canConnectWithReasonTo(input))
    XCTAssertEqual(Connection.CheckResultType.CanConnect, input.canConnectWithReasonTo(output))
  }

  func testCanConnectWithReasonTo_InvalidNull() {
    XCTAssertEqual(Connection.CheckResultType.ReasonTargetNull, output.canConnectWithReasonTo(nil))
  }

  func testCanConnectWithReasonTo_InvalidSameBlock() {
    let connection1 = createConnection(.InputValue)
    let connection2 = createConnection(.OutputValue)
    connection2.sourceBlock = connection1.sourceBlock
    XCTAssertEqual(Connection.CheckResultType.ReasonSelfConnection,
      connection1.canConnectWithReasonTo(connection2))
  }

  func testCanConnectWithReasonTo_InvalidWrongTypes() {
    let connection1 = createConnection(.OutputValue)
    let connection2 = createConnection(.OutputValue)
    XCTAssertEqual(Connection.CheckResultType.ReasonWrongType,
      connection1.canConnectWithReasonTo(connection2))
  }

  func testCanConnectWithReasonTo_InvalidAlreadyConnected() {
    BKYAssertDoesNotThrow { try self.output.connectTo(self.input) }
    let output2 = createConnection(.OutputValue)
    XCTAssertEqual(Connection.CheckResultType.ReasonMustDisconnect,
      input.canConnectWithReasonTo(output2))
  }

  func testCanConnectWithReasonTo_InvalidTypeChecks() {
    input.typeChecks = ["string"]
    output.typeChecks = ["bool"]
    XCTAssertEqual(
      Connection.CheckResultType.ReasonChecksFailed, input.canConnectWithReasonTo(output))
  }

  func testCanConnectWithReasonTo_InvalidShadowBlockForTarget() {
    XCTAssertEqual(Connection.CheckResultType.ReasonCannotSetShadowForTarget,
                   next.canConnectWithReasonTo(shadowPrevious))
    XCTAssertEqual(Connection.CheckResultType.ReasonCannotSetShadowForTarget,
                   shadowPrevious.canConnectWithReasonTo(next))
    XCTAssertEqual(Connection.CheckResultType.ReasonCannotSetShadowForTarget,
                   shadowOutput.canConnectWithReasonTo(input))
    XCTAssertEqual(Connection.CheckResultType.ReasonCannotSetShadowForTarget,
                   input.canConnectWithReasonTo(shadowOutput))
  }

  func testCanConnectShadowWithReasonTo_Valid() {
    XCTAssertEqual(Connection.CheckResultType.CanConnect,
                   input.canConnectShadowWithReasonTo(shadowOutput))
    XCTAssertEqual(Connection.CheckResultType.CanConnect,
                   shadowInput.canConnectShadowWithReasonTo(shadowOutput))
    XCTAssertEqual(Connection.CheckResultType.CanConnect,
                   next.canConnectShadowWithReasonTo(shadowPrevious))
    XCTAssertEqual(Connection.CheckResultType.CanConnect,
                   shadowNext.canConnectShadowWithReasonTo(shadowPrevious))

    // Verify it can still connect after a non-shadow has been connected
    BKYAssertDoesNotThrow { try self.input.connectTo(self.output) }
    XCTAssertEqual(
      Connection.CheckResultType.CanConnect, input.canConnectShadowWithReasonTo(shadowOutput))

    // Verify a normal connection can be made after a shadow connection
    BKYAssertDoesNotThrow { try self.next.connectShadowTo(self.shadowPrevious) }
    XCTAssertEqual(
      Connection.CheckResultType.CanConnect, next.canConnectWithReasonTo(previous))
  }

  func testCanConnectShadowWithReasonTo_InvalidNull() {
    XCTAssertEqual(
      Connection.CheckResultType.ReasonShadowNull, input.canConnectShadowWithReasonTo(nil))
  }

  func testCanConnectShadowWithReasonTo_InvalidSameBlock() {
    let connection1 = createConnection(.InputValue)
    let connection2 = createConnection(.OutputValue, shadow: true)
    connection2.sourceBlock = connection1.sourceBlock
    XCTAssertEqual(Connection.CheckResultType.ReasonSelfConnection,
                   connection1.canConnectWithReasonTo(connection2))
  }

  func testCanConnectShadowWithReasonTo_InvalidWrongTypes() {
    let connection1 = createConnection(.OutputValue, shadow: true)
    let connection2 = createConnection(.OutputValue, shadow: true)
    XCTAssertEqual(Connection.CheckResultType.ReasonWrongType,
                   connection1.canConnectWithReasonTo(connection2))
  }

  func testCanConnectShadowWithReasonTo_InvalidAlreadyConnected() {
    let shadowOutput2 = createConnection(.OutputValue, shadow: true)
    BKYAssertDoesNotThrow { try self.input.connectShadowTo(self.shadowOutput) }
    XCTAssertEqual(Connection.CheckResultType.ReasonMustDisconnect,
                   input.canConnectShadowWithReasonTo(shadowOutput2))
  }

  func testCanConnectShadowWithReasonTo_InvalidTypeChecks() {
    next.typeChecks = ["string"]
    shadowPrevious.typeChecks = ["bool"]
    XCTAssertEqual(Connection.CheckResultType.ReasonChecksFailed,
                   next.canConnectShadowWithReasonTo(shadowPrevious))
  }

  func testCanConnectShadowWithReasonTo_InvalidInferiorBlockShadowMismatch() {
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   next.canConnectShadowWithReasonTo(previous))
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   previous.canConnectShadowWithReasonTo(next))
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   shadowNext.canConnectShadowWithReasonTo(previous))
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   previous.canConnectShadowWithReasonTo(shadowNext))

    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   output.canConnectShadowWithReasonTo(input))
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   input.canConnectShadowWithReasonTo(output))
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   output.canConnectShadowWithReasonTo(shadowInput))
    XCTAssertEqual(Connection.CheckResultType.ReasonInferiorBlockShadowMismatch,
                   shadowInput.canConnectShadowWithReasonTo(output))
  }

  func testDistanceFromConnection() {
    let connection1 = createConnection(.NextStatement, 0, 0)
    let connection2 = createConnection(.InputValue, 0, 0)
    XCTAssertEqual(0, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePointMake(5.20403, 0))
    XCTAssertEqual(5.20403, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePointMake(0, 9.234))
    XCTAssertEqual(9.234, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePointMake(3, 4))
    XCTAssertEqual(5, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePointMake(-2, 0))
    XCTAssertEqual(2, connection1.distanceFromConnection(connection2))

    connection2.moveToPosition(WorkspacePointMake(0, -1.5))
    XCTAssertEqual(1.5, connection1.distanceFromConnection(connection2))

    connection1.moveToPosition(WorkspacePointMake(10, 10))
    connection2.moveToPosition(WorkspacePointMake(310, -390))
    XCTAssertEqual(500, connection1.distanceFromConnection(connection2))
  }

  func testTypeChecksMatchWithConnection() {
    let connection1 = createConnection(.PreviousStatement)
    let connection2 = createConnection(.NextStatement)

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

  private func createConnection(
    type: Connection.ConnectionType, _ x: CGFloat = 0, _ y: CGFloat = 0, shadow: Bool = false)
    -> Connection
  {
    let block = try! Block.Builder(name: "test").build(shadow: shadow)
    allBlocks.append(block) // Keep a reference of the block so it doesn't get dealloced

    let connection = Connection(type: type, sourceInput: nil)
    connection.moveToPosition(WorkspacePointMake(x, y))
    connection.sourceBlock = block
    return connection
  }
}
