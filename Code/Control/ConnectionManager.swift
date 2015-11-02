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

import Foundation

/**
Controller for `Connection` instances, where connections can be separated into groups (see 
`ConnectionManager.Group`).
*/
@objc(BKYConnectionManager)
public class ConnectionManager: NSObject {
  // MARK: - Properties

  /// The main group. By default, all connections are tracked in this group, unless specified
  /// otherwise.
  public let mainGroup = ConnectionManager.Group()

  /// Dictionary for retrieving a connection's assigned group (keyed by the connection uuid)
  private var _groupsByConnection = Dictionary<String, ConnectionManager.Group>()

  /// All groups that have been created by this manager, including `mainGroup`
  private var _groups = Set<ConnectionManager.Group>()

  // MARK: - Initializers

  public override init() {
    self._groups.insert(mainGroup)
  }

  // MARK: - Public

  /**
  Adds a new `ConnectionManager.Group` to the manager and returns it.
  */
  public func createGroup() -> ConnectionManager.Group {
    let newGroup = ConnectionManager.Group()
    _groups.insert(newGroup)
    return newGroup
  }

  /**
  Deletes a `ConnectionManager.Group` from the manager.

  - Parameter group: The group to delete
  - Throws:
  `BlocklyError`: Thrown with .ConnectionManagerError if (`group` == `mainGroup`) or if `group` is
  not empty.
  */
  public func deleteGroup(group: ConnectionManager.Group) throws {
    if group == mainGroup {
      throw BlocklyError(.ConnectionManagerError, "Cannot remove the mainGroup")
    } else if !group.allConnections.isEmpty {
      throw BlocklyError(.ConnectionManagerError, "Cannot delete non-empty group")
    }

    _groups.remove(group)
  }

  /**
  Adds this connection to the manager, listens for changes in its position, and assigns it to a
  group.

  - Parameter connection: The connection to add. If the connection was already being tracked,
  it is simply assigned to `group`.
  - Parameter group: The group to assign this connection to. If none is specified, the connection
  is assigned to `mainGroup`.
  */
  public func trackConnection(
    connection: Connection, assignToGroup group: ConnectionManager.Group? = nil) {
      let newGroup = (group ?? mainGroup)

      if let existingGroup = _groupsByConnection[connection.uuid] {
        if existingGroup == newGroup {
          // Connection is already being tracked
          return
        }
        // Each connection can only be tracked by one group at a time, remove from existing group
        existingGroup.untrackConnection(connection)
      }

      // Let the new group track this connection
      newGroup.trackConnection(connection)
      _groupsByConnection[connection.uuid] = newGroup
  }

  /**
  Removes this connection from the manager and stops listening for changes to its position.

  - Parameter connection: The connection to remove.
  */
  public func untrackConnection(connection: Connection) {
    _groupsByConnection[connection.uuid]?.untrackConnection(connection)
    _groupsByConnection[connection.uuid] = nil
  }

  /**
  Moves all connections from an existing group to a new group.

  - Parameter oldGroup: The group containing the connections to move
  - Parameter newGroup: The new group
  */
  public func moveConnectionsFromGroup(
    oldGroup: ConnectionManager.Group, toGroup newGroup:ConnectionManager.Group) {
      if oldGroup == newGroup {
        return
      }

      let allConnections = oldGroup.allConnections

      // Untrack all connections from the old group (this is faster than calling
      // oldGroup.untrackConnection(:) for each connection)
      oldGroup.untrackAllConnections()

      // Add the connection to the new group
      for connection in allConnections {
        trackConnection(connection, assignToGroup: newGroup)
      }
  }

  /**
  Find the closest compatible connection to this connection.

  - Parameter connection: The base connection for the search.
  - Parameter maxRadius: How far out to search for compatible connections.
  - Returns: The closest compatible connection and the connection group it was found in.
  */
  public func closestConnection(connection: Connection, maxRadius: CGFloat)
    -> (Connection, ConnectionManager.Group)? {
      var radius = maxRadius
      var candidate: (Connection, ConnectionManager.Group)? = nil

      for group in _groups {
        if let compatibleConnection = group.closestConnection(connection, maxRadius: radius) {
          candidate = (compatibleConnection, group)
          radius = connection.distanceFromConnection(compatibleConnection)
        }
      }

      return candidate
  }

  /**
  Find all compatible connections within the given radius.  This function is used for
  bumping so type checking does not apply.

  - Parameter connection: The base connection for the search.
  - Parameter maxRadius: How far out to search for compatible connections.
  - Returns: A list of all nearby compatible connections.
  */
  public func neighboursForConnection(connection: Connection, maxRadius: CGFloat) -> [Connection] {
    return _groups.flatMap({ $0.neighboursForConnection(connection, maxRadius: maxRadius)})
  }

  // MARK: - Internal - For testing only

  /**
  Check if the two connections can be dragged to connect to each other.

  - Parameter moving: The connection being dragged.
  - Parameter candidate: A nearby connection to check. Must be in the `ConnectionManager`, and
  therefore not be mid-drag.
  - Parameter maxRadius: The maximum radius allowed for connections.
  - Returns: True if the connection is allowed, false otherwise.
  */
  internal static func canConnect(
    moving: Connection, toConnection candidate: Connection, maxRadius: CGFloat) -> Bool {
      if moving.distanceFromConnection(candidate) > maxRadius {
        return false
      }

      // Type checking
      let canConnect = moving.canConnectWithReasonTo(candidate)
      if canConnect != .CanConnect && canConnect != .ReasonMustDisconnect {
        return false
      }

      // Don't offer to connect an already connected left (male) value plug to
      // an available right (female) value plug.  Don't offer to connect the
      // bottom of a statement block to one that's already connected.
      if candidate.connected &&
        (candidate.type == .OutputValue || candidate.type == .PreviousStatement) {
          return false
      }

      return true
  }
}

extension ConnectionManager {
  /**
  Manages a specific set of `Connection` instances.
  */
  @objc(BKYConnectionManagerGroup)
  public class Group: NSObject, ConnectionPositionListener {

    // MARK: - Properties

    private let _previousConnections = YSortedList()
    private let _nextConnections = YSortedList()
    private let _inputConnections = YSortedList()
    private let _outputConnections = YSortedList()

    private let _matchingLists: [YSortedList]
    private let _oppositeLists: [YSortedList]

    /// When the connection group's drag mode has been set to true, it's assumed that all
    /// connections are being moved together as a group. In this case, the group does not
    /// needlessly verify the internal sorted order of its connections.
    public var dragMode: Bool = false

    /// All connections managed by this group (this list is not sorted)
    internal var allConnections: [Connection] {
      return _previousConnections._connections + _nextConnections._connections +
        _inputConnections._connections + _outputConnections._connections
    }

    // MARK: - Initializers

    private override init() {
      // NOTE: If updating this, also update Connection.OPPOSITE_TYPES array.
      // The arrays are indexed by connection type codes (`connection.type.rawValue`).
      _matchingLists =
        [_previousConnections, _nextConnections, _inputConnections, _outputConnections]
      _oppositeLists =
        [_nextConnections, _previousConnections, _outputConnections, _inputConnections]
    }

    // MARK: - Internal - For testing only

    /**
    Adds this connection to the group and listens for changes in its position.

    - Parameter connection: The connection to add.
    */
    internal func trackConnection(connection: Connection) {
      addConnection(connection)
      connection.positionListeners.add(self)
    }

    /**
    Removes this connection from the group and stops listening for changes to its position.

    - Parameter connection: The connection to remove.
    */
    internal func untrackConnection(connection: Connection) {
      removeConnection(connection)
      connection.positionListeners.remove(self)
    }

    /**
    Removes all connections and stops listening for changes to their positions. Calling this method
    resets the group to its default state.
    */
    internal func untrackAllConnections() {
      for list in _matchingLists {
        list._connections.forEach { $0.positionListeners.remove(self) }
        list.removeAllConnections()
      }
    }

    /**
    Find all compatible connections within the given radius.  This function is used for
    bumping so type checking does not apply.

    - Parameter connection: The base connection for the search.
    - Parameter maxRadius: How far out to search for compatible connections.
    - Returns: A list of all nearby compatible connections.
    */
    internal func neighboursForConnection(connection: Connection, maxRadius: CGFloat)
      -> [Connection] {
        let compatibleList = _oppositeLists[connection.type.rawValue]
        return compatibleList.neighboursForConnection(connection, maxRadius: maxRadius)
    }

    /**
    Find the closest compatible connection to this connection.

    - Parameter connection: The base connection for the search.
    - Parameter maxRadius: How far out to search for compatible connections.
    - Returns: The closest compatible connection.
    */
    internal func closestConnection(connection: Connection, maxRadius: CGFloat) -> Connection? {
      if connection.connected {
        // Don't offer to connect when already connected.
        return nil
      }
      let compatibleList = _oppositeLists[connection.type.rawValue]
      return compatibleList.searchForClosestConnectionTo(connection, maxRadius: maxRadius)
    }

    internal func connectionsForType(type: Connection.ConnectionType) -> YSortedList {
      return _matchingLists[type.rawValue]
    }

    // MARK: - Private

    /**
    Figure out which list the connection belongs to and insert it.

    - Parameter connection: The connection to add.
    */
    private func addConnection(connection: Connection) {
      _matchingLists[connection.type.rawValue].addConnection(connection)
    }

    /**
    Remove a connection from the list that handles connections of its type.

    - Parameter connection: The connection to remove.
    */
    private func removeConnection(connection: Connection) {
      _matchingLists[connection.type.rawValue].removeConnection(connection)
    }

    // MARK: - ConnectionPositionListener

    public func willChangePositionForConnection(connection: Connection) {
      if dragMode {
        return
      }
      // Position will change, temporarily remove it. It will be re-added in
      // didChangePositionForConnection(:).
      removeConnection(connection)
    }

    public func didChangePositionForConnection(connection: Connection) {
      if dragMode {
        return
      }
      // This call was immediately preceded by willChangePositionForConnection(:)
      addConnection(connection)
    }
  }
}
// MARK: - Class - ConnectionManager.YSortedList

extension ConnectionManager {
  /**
  List of connections ordered by y position.  This is optimized
  for quickly finding the nearest connection when dragging a block around.
  Connections are not ordered by their x position and multiple connections may be at the same
  y position.
  */
  internal class YSortedList {
    // MARK: - Properties

    private var _connections = [Connection]()

    internal subscript(index: Int) -> Connection {
      get {
        return _connections[index]
      }
    }
    internal var isEmpty: Bool {
      return _connections.isEmpty
    }

    internal var count: Int {
      return _connections.count
    }

    // MARK: - Internal

    /**
    Insert the given connection into this list.

    -Parameter connection: The connection to insert.
    */
    internal func addConnection(connection: Connection) {
      _connections.insert(connection, atIndex: findPositionForConnection(connection))
    }

    /**
    Remove the given connection from this list.

    -Parameter connection: The connection to remove.
    */
    internal func removeConnection(connection: Connection) {
      if let removalIndex = findConnection(connection) {
        _connections.removeAtIndex(removalIndex)
      }
    }

    internal func removeAllConnections() {
      _connections.removeAll()
    }

    internal func isInYRangeForIndex(index: Int, _ baseY: CGFloat, _ maxRadius: CGFloat) -> Bool {
      let curY = _connections[index].position.y
      return (abs(curY - baseY) <= maxRadius)
    }

    /**
    Find the given connection in the given list.
    Starts by doing a binary search to find the approximate location, then linearly searches
    nearby for the exact connection.

    - Parameter connection: The connection to find.
    - Returns: The index of the connection, or nil if the connection was not found.
    */
    internal func findConnection(connection: Connection) -> Int? {
      if _connections.isEmpty {
        return nil
      }

      // Should have the right y position.
      let bestGuess = findPositionForConnection(connection)
      if bestGuess >= _connections.count {
        // Not in list.
        return nil
      }

      let yPos = connection.position.y

      // Walk forward and back on the y axis looking for the connection.
      // When found, splice it out of the array.
      var pointerMin = bestGuess
      var pointerMax = bestGuess + 1

      while (pointerMin >= 0 && _connections[pointerMin].position.y == yPos) {
        if _connections[pointerMin] == connection {
          return pointerMin
        }
        pointerMin--
      }
      while (pointerMax < _connections.count && _connections[pointerMax].position.y == yPos) {
        if _connections[pointerMax] == connection {
          return pointerMax
        }
        pointerMax++
      }
      return nil
    }

    /**
    Finds a candidate position for inserting this connection into the given list.
    This will be in the correct y order but makes no guarantees about ordering in the x axis.

    - Parameter connection: The connection to insert.
    - Returns: The candidate index.
    */
    internal func findPositionForConnection(connection: Connection) -> Int {
      if _connections.isEmpty {
        return 0
      }

      var pointerMin = 0
      var pointerMax = _connections.count
      let yPos = connection.position.y

      while (pointerMin < pointerMax) {
        let pointerMid = (pointerMin + pointerMax) / 2
        let pointerY = _connections[pointerMid].position.y
        if (pointerY < yPos) {
          pointerMin = pointerMid + 1
        } else if (pointerY > yPos) {
          pointerMax = pointerMid
        } else {
          pointerMin = pointerMid
          break
        }
      }
      return pointerMin
    }

    internal func searchForClosestConnectionTo(connection: Connection, maxRadius: CGFloat)
      -> Connection? {
        // Don't bother.
        if _connections.isEmpty {
          return nil
        }

        let baseY = connection.position.y
        // findPositionForConnection finds an index for insertion, which is always after any
        // block with the same y index.  We want to search both forward and back, so search
        // on both sides of the index.
        let closestIndex = findPositionForConnection(connection)

        var bestConnection: Connection?
        var bestRadius = maxRadius

        // Walk forward and back on the y axis looking for the closest x,y point.
        var pointerMin = closestIndex - 1
        while (pointerMin >= 0 && isInYRangeForIndex(pointerMin, baseY, maxRadius)) {
          let temp = _connections[pointerMin]
          if ConnectionManager.canConnect(connection, toConnection: temp, maxRadius: bestRadius) {
            bestConnection = temp
            bestRadius = temp.distanceFromConnection(connection)
          }
          pointerMin--
        }

        var pointerMax = closestIndex
        while (pointerMax < _connections.count &&
          isInYRangeForIndex(pointerMax, baseY, maxRadius)) {
            let temp = _connections[pointerMax]
            if ConnectionManager.canConnect(connection, toConnection: temp, maxRadius: bestRadius) {
              bestConnection = temp
              bestRadius = temp.distanceFromConnection(connection)
            }
            pointerMax++
        }
        return bestConnection
    }

    internal func neighboursForConnection(connection: Connection, maxRadius: CGFloat)
      -> [Connection] {
        var neighbours = [Connection]()
        // Don't bother.
        if _connections.isEmpty {
          return neighbours
        }

        let baseY = connection.position.y
        // findPositionForConnection finds an index for insertion, which is always after any
        // block with the same y index.  We want to search both forward and back, so search
        // on both sides of the index.
        let closestIndex = findPositionForConnection(connection)

        // Walk forward and back on the y axis looking for the closest x,y point.
        // If both connections are connected, that's probably fine.  But if
        // either one of them is unconnected, then there could be confusion.
        var pointerMin = closestIndex - 1
        while (pointerMin >= 0 && isInYRangeForIndex(pointerMin, baseY, maxRadius)) {
          let temp = _connections[pointerMin]
          if ((!connection.connected || !temp.connected) &&
            ConnectionManager.canConnect(connection, toConnection: temp, maxRadius: maxRadius)) {
              neighbours.append(temp)
          }
          pointerMin--
        }

        var pointerMax = closestIndex
        while (pointerMax < _connections.count &&
          isInYRangeForIndex(pointerMax, baseY, maxRadius)) {
            let temp = _connections[pointerMax]
            if ((!connection.connected || !temp.connected) &&
              ConnectionManager.canConnect(connection, toConnection: temp, maxRadius: maxRadius)) {
                neighbours.append(temp)
            }
            pointerMax++
        }
        return neighbours
    }

    internal func contains(connection: Connection) -> Bool {
      return findConnection(connection) != nil
    }
  }
}
