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

/**
Tests for `ConnectionManager`.
*/
class ConnectionManagerTest: XCTestCase {

  // MARK: - Properties

  /// The manager to test
  private var manager: ConnectionManager!

  /// Test workspace
  private var workspace: Workspace!

  // MARK: - Initialization

  override func setUp() {
    super.setUp()

    workspace = Workspace(layoutFactory: nil, isFlyout: false)
    manager = ConnectionManager()
  }

  // MARK: - ConnectionManager Tests

  func testConnectionManagerAdd() {
    var conn = Connection(type: .PreviousStatement)
    manager.addConnection(conn)
    XCTAssertTrue(manager.connectionsForType(.PreviousStatement).contains(conn))

    conn = Connection(type: .NextStatement)
    manager.addConnection(conn)
    XCTAssertTrue(manager.connectionsForType(.NextStatement).contains(conn))

    conn = Connection(type: .InputValue)
    manager.addConnection(conn)
    XCTAssertTrue(manager.connectionsForType(.InputValue).contains(conn))

    conn = Connection(type: .OutputValue)
    manager.addConnection(conn)
    XCTAssertTrue(manager.connectionsForType(.OutputValue).contains(conn))
  }

  func testConnectionManagerMoveTo() {
    let offsetX: CGFloat = 10
    let offsetY: CGFloat  = -10
    let offset = WorkspacePointMake(offsetX, offsetY)
    let conn = createConnection(0, 0, .PreviousStatement)
    manager.addConnection(conn)

    // Move to this position + the given offset.
    var moveX: CGFloat = 15
    var moveY: CGFloat = 20
    manager.moveConnection(conn, toLocation: WorkspacePointMake(moveX, moveY), withOffset: offset)
    XCTAssertEqual(moveX + offsetX, conn.position.x)
    XCTAssertEqual(moveY + offsetY, conn.position.y)
    // Connection should still be in the list
    XCTAssertTrue(manager.connectionsForType(.PreviousStatement).contains(conn))

    manager.removeConnection(conn)
    conn.dragMode = true
    // Moving a connection while being dragged should update the connection itself but not
    // put it back into the connection manager.
    moveX = 10
    moveY = 100
    manager.moveConnection(conn, toLocation: WorkspacePointMake(moveX, moveY), withOffset: offset)
    XCTAssertFalse(manager.connectionsForType(.PreviousStatement).contains(conn))
    XCTAssertEqual(moveX + offsetX, conn.position.x)
    XCTAssertEqual(moveY + offsetY, conn.position.y)
  }

  func testConnectionManagerIsConnectionAllowed() {
    // Two connections of opposite types near each other
    let one = createConnection(5 /* x */, 10 /* y */, .InputValue)
    let two = createConnection(10 /* x */, 15 /* y */, .OutputValue)

    XCTAssertTrue(ConnectionManager.canConnect(one, toConnection: two, maxRadius: 20.0))
    // Move connections farther apart
    two.position.x = 100
    two.position.y = 100
    XCTAssertFalse(ConnectionManager.canConnect(one, toConnection: two, maxRadius: 20.0))

    // Don't offer to connect an already connected left (male) value plug to
    // an available right (female) value plug.
    let three = createConnection(0, 0, .OutputValue)
    XCTAssertTrue(ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0))
    let four = createConnection(0, 0, .InputValue)
    if (try? three.connectTo(four)) == nil {
      XCTFail("Could not connect connections 3 and 4")
    }
    XCTAssertFalse(ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0))

    // Don't connect two connections on the same block
    two.sourceBlock = one.sourceBlock
    XCTAssertFalse(ConnectionManager.canConnect(one, toConnection: two, maxRadius: 1000.0))
  }

  func testConnectionManagerIsConnectionAllowedNext() {
    let one = createConnection(0, 0, .NextStatement,
      sourceInput: Input(type: .Value, name: "test input", workspace: workspace))
    let two = createConnection(0, 0, .NextStatement,
      sourceInput: Input(type: .Value, name: "test input", workspace: workspace))

    // Don't offer to connect the bottom of a statement block to one that's already connected.
    let three = createConnection(0, 0, .PreviousStatement)
    XCTAssertTrue(ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0))
    if (try? three.connectTo(two)) == nil {
      XCTFail("Could not connect connections 3 and 4")
    }
    XCTAssertFalse(ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0))
  }

  // MARK: - ConnectionManager.YSortedList Tests

  func testYSortedListFindPosition() {
    let list = manager.connectionsForType(.PreviousStatement)
    list.addConnection(createConnection(0, 0, .PreviousStatement))
    list.addConnection(createConnection(0, 1, .PreviousStatement))
    list.addConnection(createConnection(0, 2, .PreviousStatement))
    list.addConnection(createConnection(0, 4, .PreviousStatement))
    list.addConnection(createConnection(0, 5, .PreviousStatement))

    XCTAssertEqual(5, list.count)
    let conn = createConnection(0, 3, .PreviousStatement)
    XCTAssertEqual(3, list.findPositionForConnection(conn))
  }

  func testYSortedListFind() {
    let previousList = manager.connectionsForType(.PreviousStatement)
    for (var i = 0; i < 10; i++) {
      previousList.addConnection(createConnection(CGFloat(i), 0, .PreviousStatement))
      previousList.addConnection(createConnection(0, CGFloat(i), .PreviousStatement))
    }

    var conn = createConnection(3, 3, .PreviousStatement)
    previousList.addConnection(conn)
    XCTAssertEqual(conn, previousList[previousList.findConnection(conn)!])

    conn = createConnection(3, 3, .PreviousStatement)
    XCTAssertEqual(nil, previousList.findConnection(conn))
  }

  func testYSortedListOrdered() {
    let list = manager.connectionsForType(.PreviousStatement)
    for (var i = 0; i < 10; i++) {
      list.addConnection(createConnection(0, CGFloat(9 - i), .PreviousStatement))
    }

    for (var i = 0; i < 10; i++) {
      XCTAssertEqual(CGFloat(i), list[i].position.y)
    }

    // quasi-random
    let xCoords: [CGFloat] = [-29, -47, -77, 2, 43, 34, -59, -52, -90, -36, -91, 38, 87, -20, 60, 4,
      -57, 65, -37, -81, 57, 58, -96, 1, 67, -79, 34, 93, -90, -99, -62, 4, 11, -36, -51, -72,
      3, -50, -24, -45, -92, -38, 37, 24, -47, -73, 79, -20, 99, 43, -10, -87, 19, 35,
      -62, -36, 49, 86, -24, -47, -89, 33, -44, 25, -73, -91, 85, 6, 0, 89, -94, 36, -35,
      84, -9, 96, -21, 52, 10, -95, 7, -67, -70, 62, 9, -40, -95, -9, -94, 55, 57, -96,
      55, 8, -48, -57, -87, 81, 23, 65]
    let yCoords: [CGFloat] = [-81, 82, 5, 47, 30, 57, -12, 28, 38, 92, -25, -20, 23, -51, 73, -90,
      8, 28, -51, -15, 81, -60, -6, -16, 77, -62, -42, -24, 35, 95, -46, -7, 61, -16, 14, 91, 57,
      -38, 27, -39, 92, 47, -98, 11, -33, -72, 64, 38, -64, -88, -35, -59, -76, -94, 45,
      -25, -100, -95, 63, -97, 45, 98, 99, 34, 27, 52, -18, -45, 66, -32, -38, 70, -73,
      -23, 5, -2, -13, -9, 48, 74, -97, -11, 35, -79, -16, -77, 83, -57, -53, 35, -44,
      100, -27, -15, 5, 39, 33, -19, -20, -95]

    for (var i = 0; i < xCoords.count; i++) {
      list.addConnection(createConnection(xCoords[i], yCoords[i], .PreviousStatement))
    }

    for (var i = 1; i < xCoords.count; i++) {
      XCTAssertTrue(list[i].position.y >= list[i - 1].position.y)
    }
  }

  // Test YSortedList
  func testYSortedListSearchForClosest() {
    let list = manager.connectionsForType(.PreviousStatement)

    // search an empty list
    XCTAssertEqual(nil, searchList(list, x: 10, y: 10, radius: 100))

    list.addConnection(createConnection(100, 0, .PreviousStatement))
    XCTAssertEqual(nil, searchList(list, x: 0, y: 0, radius: 5))
    list.removeAllConnections()

    for (var i = 0; i < 10; i++) {
      list.addConnection(createConnection(0, CGFloat(i), .PreviousStatement))
    }

    // should be at 0, 9
    let last = list[list.count - 1]
    // correct connection is last in list many connections in radius
    XCTAssertEqual(last, searchList(list, x: 0, y: 10, radius: 15))
    // Nothing nearby.
    XCTAssertEqual(nil, searchList(list, x: 100, y: 100, radius: 3))
    // first in list, exact match
    XCTAssertEqual(list[0], searchList(list, x: 0, y: 0, radius: 0))

    list.addConnection(createConnection(6, 6, .PreviousStatement))
    list.addConnection(createConnection(5, 5, .PreviousStatement))

    let result = searchList(list, x: 4, y: 6, radius: 3)
    XCTAssertEqual(5, result?.position.x)
    XCTAssertEqual(5, result?.position.y)
  }

  func testYSortedListGetNeighbours() {

    let list = manager.connectionsForType(.PreviousStatement)

    // Search an empty list
    XCTAssertTrue(getNeighbourHelper(list, x: 10, y: 10, radius: 100).isEmpty)

    // Make a list
    for (var i = 0; i < 10; i++) {
      list.addConnection(createConnection(0, CGFloat(i), .PreviousStatement))
    }

    // Test block belongs at beginning
    var result = getNeighbourHelper(list, x: 0, y: 0, radius: 4)
    XCTAssertEqual(5, result.count)
    for (var i = 0; i < result.count; i++) {
      XCTAssertTrue(result.contains(list[i]))
    }

    // Test block belongs at middle
    result = getNeighbourHelper(list, x: 0, y: 4, radius: 2)
    XCTAssertEqual(5, result.count)
    for (var i = 0; i < result.count; i++) {
      XCTAssertTrue(result.contains(list[i + 2]))
    }

    // Test block belongs at end
    result = getNeighbourHelper(list, x: 0, y: 9, radius: 4)
    XCTAssertEqual(5, result.count)
    for (var i = 0; i < result.count; i++) {
      XCTAssertTrue(result.contains(list[i + 5]))
    }

    // Test block has no neighbours due to being out of range in the x direction
    result = getNeighbourHelper(list, x: 10, y: 9, radius: 4)
    XCTAssertTrue(result.isEmpty)

    // Test block has no neighbours due to being out of range in the y direction
    result = getNeighbourHelper(list, x: 0, y: 19, radius: 4)
    XCTAssertTrue(result.isEmpty)

    // Test block has no neighbours due to being out of range diagonally
    result = getNeighbourHelper(list, x: -2, y: -2, radius: 2)
    XCTAssertTrue(result.isEmpty)
  }

  // MARK: - Private Helpers

  private func getNeighbourHelper(
    list: ConnectionManager.YSortedList, x: CGFloat, y: CGFloat, radius: CGFloat) -> [Connection] {
      return list.neighboursForConnection(createConnection(x, y, .NextStatement), maxRadius: radius)
  }

  private func searchList(
    list: ConnectionManager.YSortedList, x: CGFloat, y: CGFloat, radius: CGFloat) -> Connection? {
      let connection = createConnection(x, y, .NextStatement)
      return list.searchForClosestConnectionTo(connection, maxRadius: radius)
  }

  private func createConnection(
    x: CGFloat, _ y: CGFloat, _ type: Connection.ConnectionType, sourceInput: Input? = nil)
    -> Connection {
      let conn = Connection(type: type, sourceInput: sourceInput)
      conn.position.x = x
      conn.position.y = y
      conn.sourceBlock = Block.Builder(identifier: "test", workspace: workspace).build()
      return conn
  }
}
