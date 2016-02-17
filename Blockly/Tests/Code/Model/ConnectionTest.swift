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

class ConnectionTest: XCTestCase {

  var _workspace: Workspace!

  // MARK: - Setup

  override func setUp() {
    _workspace = Workspace()
  }

  // MARK: - Tests

  func testConnectInputOutput() {
    do {
      let input = createConnection(.InputValue)
      let output = createConnection(.OutputValue)
      XCTAssertFalse(input.connected)
      XCTAssertFalse(output.connected)

      try input.connectTo(output)

      XCTAssertTrue(input.connected)
      XCTAssertTrue(output.connected)
      XCTAssertEqual(output, input.targetConnection)
      XCTAssertEqual(input, output.targetConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect connections together: \(error)")
    }
  }

  func testConnectOutputInput() {
    do {
      let input = createConnection(.InputValue)
      let output = createConnection(.OutputValue)
      XCTAssertFalse(input.connected)
      XCTAssertFalse(output.connected)

      try output.connectTo(input)

      XCTAssertTrue(input.connected)
      XCTAssertTrue(output.connected)
      XCTAssertEqual(output, input.targetConnection)
      XCTAssertEqual(input, output.targetConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect connections together: \(error)")
    }
  }

  func testConnectPreviousNext() {
    do {
      let previous = createConnection(.PreviousStatement)
      let next = createConnection(.NextStatement)
      XCTAssertFalse(previous.connected)
      XCTAssertFalse(next.connected)

      try previous.connectTo(next)

      XCTAssertTrue(previous.connected)
      XCTAssertTrue(next.connected)
      XCTAssertEqual(next, previous.targetConnection)
      XCTAssertEqual(previous, next.targetConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect connections together: \(error)")
    }
  }

  func testConnectNextPrevious() {
    do {
      let previous = createConnection(.PreviousStatement)
      let next = createConnection(.NextStatement)
      XCTAssertFalse(previous.connected)
      XCTAssertFalse(next.connected)

      try next.connectTo(previous)

      XCTAssertTrue(previous.connected)
      XCTAssertTrue(next.connected)
      XCTAssertEqual(next, previous.targetConnection)
      XCTAssertEqual(previous, next.targetConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect connections together: \(error)")
    }
  }

  func testDisconnect() {
    do {
      let input = createConnection(.InputValue)
      let output = createConnection(.OutputValue)
      try input.connectTo(output)

      XCTAssertTrue(input.connected)
      XCTAssertTrue(output.connected)

      input.disconnect()

      XCTAssertNil(input.targetConnection)
      XCTAssertNil(output.targetConnection)
      XCTAssertFalse(input.connected)
      XCTAssertFalse(output.connected)
    } catch let error as NSError {
      XCTFail("Couldn't connect connections together: \(error)")
    }
  }

  func testCanConnectWithReasonTo() {
    // Valid - previous /next
    var connection1 = createConnection(.PreviousStatement)
    var connection2 = createConnection(.NextStatement)
    XCTAssertEqual(Connection.CheckResultType.CanConnect,
      connection1.canConnectWithReasonTo(connection2))

    // Valid - output / input
    connection1 = createConnection(.OutputValue)
    connection2 = createConnection(.InputValue)
    XCTAssertEqual(Connection.CheckResultType.CanConnect,
      connection1.canConnectWithReasonTo(connection2))

    // Invalid - null
    connection1 = createConnection(.OutputValue)
    XCTAssertEqual(Connection.CheckResultType.ReasonTargetNull,
      connection1.canConnectWithReasonTo(nil))

    // Invalid - same block
    connection1 = createConnection(.OutputValue)
    connection2 = createConnection(.OutputValue)
    connection2.sourceBlock = connection1.sourceBlock
    XCTAssertEqual(Connection.CheckResultType.ReasonSelfConnection,
      connection1.canConnectWithReasonTo(connection2))

    // Invalid - wrong types
    connection1 = createConnection(.OutputValue)
    connection2 = createConnection(.OutputValue)
    XCTAssertEqual(Connection.CheckResultType.ReasonWrongType,
      connection1.canConnectWithReasonTo(connection2))

    // Invalid - already connected
    do {
      connection1 = createConnection(.InputValue)
      connection2 = createConnection(.OutputValue)
      try connection1.connectTo(connection2)
      let connection3 = createConnection(.OutputValue)
      XCTAssertEqual(Connection.CheckResultType.ReasonMustDisconnect,
        connection1.canConnectWithReasonTo(connection3))
    } catch let error as NSError {
      XCTFail("Couldn't connect connections together: \(error)")
    }

    // Invalid - type checks
    connection1 = createConnection(.InputValue)
    connection1.typeChecks = ["string"]
    connection2 = createConnection(.OutputValue)
    connection2.typeChecks = ["bool"]
    XCTAssertEqual(Connection.CheckResultType.ReasonChecksFailed,
      connection1.canConnectWithReasonTo(connection2))
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

  private func createConnection(type: Connection.ConnectionType, _ x: CGFloat = 0, _ y: CGFloat = 0)
    -> Connection
  {
    let block = try! Block.Builder(name: "test").build()
    try! _workspace.addBlockTree(block)

    let connection = Connection(type: type, sourceInput: nil)
    connection.moveToPosition(WorkspacePointMake(x, y))
    connection.sourceBlock = block
    return connection
  }
}
