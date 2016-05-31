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

    workspace = Workspace()
    manager = ConnectionManager()
  }

  // MARK: - ConnectionManager Tests

  func testConnectionManagerTrack() {
    var conn = Connection(type: .PreviousStatement)
    manager.trackConnection(conn)
    XCTAssertTrue(manager.mainGroup.connectionsForType(.PreviousStatement).contains(conn))

    conn = Connection(type: .NextStatement)
    manager.trackConnection(conn)
    XCTAssertTrue(manager.mainGroup.connectionsForType(.NextStatement).contains(conn))

    conn = Connection(type: .InputValue)
    manager.trackConnection(conn)
    XCTAssertTrue(manager.mainGroup.connectionsForType(.InputValue).contains(conn))

    conn = Connection(type: .OutputValue)
    manager.trackConnection(conn)
    XCTAssertTrue(manager.mainGroup.connectionsForType(.OutputValue).contains(conn))
  }

  func testConnectionManagerMoveTo() {
    let offsetX: CGFloat = 10
    let offsetY: CGFloat  = -10
    let offset = WorkspacePointMake(offsetX, offsetY)
    let conn = createConnection(0, 0, .PreviousStatement)
    manager.trackConnection(conn)

    // Move to this position + the given offset.
    var moveX: CGFloat = 15
    var moveY: CGFloat = 20
    conn.moveToPosition(WorkspacePointMake(moveX, moveY), withOffset: offset)
    XCTAssertEqual(moveX + offsetX, conn.position.x)
    XCTAssertEqual(moveY + offsetY, conn.position.y)
    // Connection should still be in the list
    XCTAssertTrue(manager.mainGroup.connectionsForType(.PreviousStatement).contains(conn))

    manager.untrackConnection(conn)

    // Moving a connection should update the connection itself but it should no longer be in the
    // connection manager.
    moveX = 10
    moveY = 100
    conn.moveToPosition(WorkspacePointMake(moveX, moveY), withOffset: offset)
    XCTAssertFalse(manager.mainGroup.connectionsForType(.PreviousStatement).contains(conn))
    XCTAssertEqual(moveX + offsetX, conn.position.x)
    XCTAssertEqual(moveY + offsetY, conn.position.y)
  }

  func testConnectionManagerIsConnectionAllowed() {
    // Two connections of opposite types near each other
    let one = createConnection(5 /* x */, 10 /* y */, .InputValue)
    let two = createConnection(10 /* x */, 15 /* y */, .OutputValue)

    XCTAssertTrue(
      ConnectionManager.canConnect(one, toConnection: two, maxRadius: 20.0, allowShadows: true))
    // Move connections farther apart
    two.moveToPosition(WorkspacePointMake(100, 100))
    XCTAssertFalse(
      ConnectionManager.canConnect(one, toConnection: two, maxRadius: 20.0, allowShadows: true))

    // Don't offer to connect an already connected left (male) value plug to
    // an available right (female) value plug.
    let three = createConnection(0, 0, .OutputValue)
    XCTAssertTrue(
      ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0, allowShadows: true))
    let four = createConnection(0, 0, .InputValue)
    if (try? three.connectTo(four)) == nil {
      XCTFail("Could not connect connections 3 and 4")
    }
    XCTAssertFalse(
      ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0, allowShadows: true))

    // Don't connect two connections on the same block
    two.sourceBlock = one.sourceBlock
    XCTAssertFalse(
      ConnectionManager.canConnect(one, toConnection: two, maxRadius: 1000.0, allowShadows: true))
  }

  func testConnectionManagerIsConnectionAllowedNext() {
    let one = createConnection(0, 0, .NextStatement,
      sourceInput: Input.Builder(type: .Value, name: "test input").build())
    let two = createConnection(0, 0, .NextStatement,
      sourceInput: Input.Builder(type: .Value, name: "test input").build())

    // Don't offer to connect the bottom of a statement block to one that's already connected.
    let three = createConnection(0, 0, .PreviousStatement)
    XCTAssertTrue(
      ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0, allowShadows: true))
    if (try? three.connectTo(two)) == nil {
      XCTFail("Could not connect connections 3 and 4")
    }
    XCTAssertFalse(
      ConnectionManager.canConnect(one, toConnection: three, maxRadius: 20.0, allowShadows: true))
  }

  // MARK: - ConnectionManager.Group Tests

  func testConnectionManagerStartGroup() {
    let connectionGroup = manager.startGroupForBlock(nil)
    let conn = Connection(type: .PreviousStatement)
    manager.trackConnection(conn, assignToGroup: connectionGroup)
    XCTAssertTrue(connectionGroup.connectionsForType(.PreviousStatement).contains(conn))
    XCTAssertTrue(!manager.mainGroup.connectionsForType(.PreviousStatement).contains(conn))
  }

  func testConnectionManagerDeleteGroup() {
    let connectionGroup = manager.startGroupForBlock(nil)
    let conn = Connection(type: .InputValue)
    manager.trackConnection(conn, assignToGroup: connectionGroup)

    do {
      try manager.deleteGroup(connectionGroup)
      XCTFail("Should not be able to delete non-empty group")
    } catch {
    }

    do {
      try manager.deleteGroup(manager.mainGroup)
      XCTFail("Should not be able to delete the main group")
    } catch {
    }

    manager.untrackConnection(conn)

    do {
      try manager.deleteGroup(connectionGroup)
    } catch let error as NSError {
      XCTFail("Could not delete group: \(error)")
    }
  }

  func testConnectionManagerMergeGroups() {
    let group1 = manager.startGroupForBlock(nil)
    let group2 = manager.startGroupForBlock(nil)

    var connections = [Connection]()
    for i in 0 ..< 12 {
      let connectionType = Connection.ConnectionType(rawValue: i % 4)
      connections.append(createConnection(CGFloat(i), CGFloat(i), connectionType!))
      manager.trackConnection(connections[i], assignToGroup: group1)
    }

    // Verify all connections are in group 1
    for connection in connections {
      XCTAssertTrue(group1.allConnections.contains(connection))
      XCTAssertTrue(connection.positionDelegate === group1)
      XCTAssertFalse(group2.allConnections.contains(connection))
      XCTAssertFalse(connection.positionDelegate === group2)
    }
    XCTAssertEqual(connections.count, group1.allConnections.count)
    XCTAssertEqual(0, group2.allConnections.count)

    manager.mergeGroup(group1, intoGroup: group2)

    // Verify all connections are in group 2
    for connection in connections {
      XCTAssertFalse(group1.allConnections.contains(connection))
      XCTAssertFalse(connection.positionDelegate === group1)
      XCTAssertTrue(group2.allConnections.contains(connection))
      XCTAssertTrue(connection.positionDelegate === group2)
    }
    XCTAssertEqual(0, group1.allConnections.count)
    XCTAssertEqual(connections.count, group2.allConnections.count)
  }

  // MARK: - ConnectionManager.YSortedList Tests

  func testYSortedListFindPosition() {
    let list = manager.mainGroup.connectionsForType(.PreviousStatement)
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
    let previousList = manager.mainGroup.connectionsForType(.PreviousStatement)
    for i in 0 ..< 10 {
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
    let list = manager.mainGroup.connectionsForType(.PreviousStatement)
    for i in 0 ..< 10 {
      list.addConnection(createConnection(0, CGFloat(9 - i), .PreviousStatement))
    }

    for i in 0 ..< 10 {
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

    for i in 0 ..< xCoords.count {
      list.addConnection(createConnection(xCoords[i], yCoords[i], .PreviousStatement))
    }

    for i in 1 ..< xCoords.count {
      XCTAssertTrue(list[i].position.y >= list[i - 1].position.y)
    }
  }

  // Test YSortedList
  func testYSortedListSearchForClosest() {
    let list = manager.mainGroup.connectionsForType(.PreviousStatement)

    // search an empty list
    XCTAssertEqual(nil, searchList(list, x: 10, y: 10, radius: 100))

    list.addConnection(createConnection(100, 0, .PreviousStatement))
    XCTAssertEqual(nil, searchList(list, x: 0, y: 0, radius: 5))
    list.removeAllConnections()

    for i in 0 ..< 10 {
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
    let list = manager.mainGroup.connectionsForType(.PreviousStatement)

    // Search an empty list
    XCTAssertTrue(getNeighbourHelper(list, x: 10, y: 10, radius: 100).isEmpty)

    // Make a list
    for i in 0 ..< 10 {
      list.addConnection(createConnection(0, CGFloat(i), .PreviousStatement))
    }

    // Test block belongs at beginning
    var result = getNeighbourHelper(list, x: 0, y: 0, radius: 4)
    XCTAssertEqual(5, result.count)
    for i in 0 ..< result.count {
      XCTAssertTrue(result.contains(list[i]))
    }

    // Test block belongs at middle
    result = getNeighbourHelper(list, x: 0, y: 4, radius: 2)
    XCTAssertEqual(5, result.count)
    for i in 0 ..< result.count {
      XCTAssertTrue(result.contains(list[i + 2]))
    }

    // Test block belongs at end
    result = getNeighbourHelper(list, x: 0, y: 9, radius: 4)
    XCTAssertEqual(5, result.count)
    for i in 0 ..< result.count {
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

  func testYSortedListTransferConnectionsToEmptyGroup() {
    let group1 = manager.startGroupForBlock(nil)
    let group2 = manager.startGroupForBlock(nil)
    let list1 = group1.connectionsForType(.PreviousStatement)
    let list2 = group2.connectionsForType(.PreviousStatement)

    // Create connections
    let yCoords1: [CGFloat] = [-25, -24.3, 1, 6, 29, -2, 4]

    var allConnections = [Connection]()
    allConnections.appendContentsOf(createConnectionsForList(list1, yCoords: yCoords1))

    // Transfer connections
    list1.transferConnectionsToList(list2)

    // Verify all connections are in list2 and that they are sorted
    for connection in allConnections {
      XCTAssertFalse(list1.contains(connection))
      XCTAssertTrue(list2.contains(connection))
    }
    XCTAssertTrue(isListSorted(list2))
  }

  func testYSortedListTransferConnectionsToNonEmptyGroup1() {
    let group1 = manager.startGroupForBlock(nil)
    let group2 = manager.startGroupForBlock(nil)
    let list1 = group1.connectionsForType(.PreviousStatement)
    let list2 = group2.connectionsForType(.PreviousStatement)

    // Create connections
    let yCoords1: [CGFloat] = [-3, 0, 1, 5, 5, 6, 8]
    let yCoords2: [CGFloat] = [0, 0.00001, 2, 4, 5, 5, 7, 8, 8.0001]

    var allConnections = [Connection]()
    allConnections.appendContentsOf(createConnectionsForList(list1, yCoords: yCoords1))
    allConnections.appendContentsOf(createConnectionsForList(list2, yCoords: yCoords2))

    // Transfer connections
    list1.transferConnectionsToList(list2)

    // Verify all connections are in list2 and that they are sorted
    for connection in allConnections {
      XCTAssertFalse(list1.contains(connection))
      XCTAssertTrue(list2.contains(connection))
    }
    XCTAssertTrue(isListSorted(list2))
  }

  func testYSortedListTransferConnectionsToNonEmptyGroup2() {
    let group1 = manager.startGroupForBlock(nil)
    let group2 = manager.startGroupForBlock(nil)
    let list1 = group1.connectionsForType(.PreviousStatement)
    let list2 = group2.connectionsForType(.PreviousStatement)

    // Create connections
    let yCoords1: [CGFloat] = [-3, 0, 1, 5, 5, 6, 8]
    let yCoords2: [CGFloat] = [-5, -3, -2, 0, 3, 8]

    var allConnections = [Connection]()
    allConnections.appendContentsOf(createConnectionsForList(list1, yCoords: yCoords1))
    allConnections.appendContentsOf(createConnectionsForList(list2, yCoords: yCoords2))

    // Transfer connections
    list1.transferConnectionsToList(list2)

    // Verify all connections are in list2 and that they are sorted
    for connection in allConnections {
      XCTAssertFalse(list1.contains(connection))
      XCTAssertTrue(list2.contains(connection))
    }
    XCTAssertTrue(isListSorted(list2))
  }

  // MARK: - Private Helpers

  private func createConnectionsForList(list: ConnectionManager.YSortedList, yCoords: [CGFloat])
    -> [Connection] {
      var connections = [Connection]()
      for i in 0 ..< yCoords.count {
        let connection = createConnection(CGFloat(i), CGFloat(yCoords[i]), .PreviousStatement)
        list.addConnection(connection)
        connections.append(connection)
      }
      return connections
  }

  private func isListSorted(list: ConnectionManager.YSortedList) -> Bool {
    var currentPosY: CGFloat?

    for i in 0 ..< list.count {
      if currentPosY != nil && list[i].position.y < currentPosY! {
        // The value at list[i] has a y-pos that is less than the previous value
        return false
      }
      currentPosY = list[i].position.y
    }

    return true
  }

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
    -> Connection
  {
      let block = try! Block.Builder(name: "test").build()
      try! workspace.addBlockTree(block)

      let conn = Connection(type: type, sourceInput: sourceInput)
      conn.moveToPosition(WorkspacePointMake(x, y))
      conn.sourceBlock = block

      return conn
  }
}
