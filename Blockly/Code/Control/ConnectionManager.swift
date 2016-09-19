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
public final class ConnectionManager: NSObject {
  public typealias ConnectionPair =
    (moving: Connection, target: Connection, fromConnectionManagerGroup: ConnectionManager.Group)

  // MARK: - Properties

  /// The main group. By default, all connections are tracked in this group, unless specified
  /// otherwise.
  public let mainGroup: ConnectionManager.Group

  /// Validator for accepting/rejecting block-level connection logic.
  public let connectionValidator: ConnectionValidator

  /// Dictionary for retrieving a connection's assigned group (keyed by the connection uuid)
  fileprivate var _groupsByConnection = Dictionary<String, ConnectionManager.Group>()

  /// All groups that have been created by this manager, including `mainGroup`
  fileprivate var _groups = Set<ConnectionManager.Group>()

  // MARK: - Initializers

  public init(connectionValidator: ConnectionValidator = DefaultConnectionValidator()) {
    self.connectionValidator = connectionValidator
    self.mainGroup = ConnectionManager.Group(ownerBlock: nil)
    super.init()
    self._groups.insert(mainGroup)
  }

  // MARK: - Public

  /**
  Adds a new `ConnectionManager.Group` to the manager for a given block.

  - Parameter block: If this value is specified, all connections underneath this block's tree are
  automatically moved to the newly created connection group. This value is also assigned as the
  `ownerBlock` of the connection group.
  - Returns: The newly created connection group
  */
  public func startGroupForBlock(_ block: Block?) -> ConnectionManager.Group {
    let newGroup = ConnectionManager.Group(ownerBlock: block)
    _groups.insert(newGroup)

    if let childConnections = block?.allConnectionsForTree() {
      // Change the connection group for all affected connections to the new one created
      // for the drag gesture
      for connection in childConnections {
        trackConnection(connection, assignToGroup: newGroup)
      }
    }

    return newGroup
  }

  /**
  Moves all connections from one group to another group. The first group is automatically
  deleted after this operation is completed (unless both groups are the same).

  - Parameter fromGroup: The group containing the connections to move

  - Parameter intoGroup: The receiving group. If this value is nil, the `mainGroup` is used by
  default.
  */
  public func mergeGroup(_ fromGroup: ConnectionManager.Group, intoGroup: ConnectionManager.Group?)
  {
    let newGroup = (intoGroup ?? self.mainGroup)
    if fromGroup == newGroup {
      return
    }

    let allConnections = fromGroup.allConnections

    fromGroup.transferConnectionsToGroup(newGroup)

    for connection in allConnections {
      // Update dictionary of groups by connection
      _groupsByConnection[connection.uuid] = newGroup
    }

    // Delete the group that was merged
    do {
      try deleteGroup(fromGroup)
    } catch let error as NSError {
      bky_assertionFailure("Could not delete connection group: \(error)")
    }
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
    _ connection: Connection, assignToGroup group: ConnectionManager.Group? = nil) {
      let newGroup = (group ?? mainGroup)

      if _groupsByConnection[connection.uuid] == newGroup {
        // Connection is already being tracked by this group, do nothing
        return
      }

      // Each connection can only be tracked by one group at a time, remove from existing group
      untrackConnection(connection)

      // Let the new group track this connection
      newGroup.trackConnection(connection)
      _groupsByConnection[connection.uuid] = newGroup
  }

  /**
  Removes this connection from the manager and stops listening for changes to its position.

  - Parameter connection: The connection to remove.
  */
  public func untrackConnection(_ connection: Connection) {
    _groupsByConnection[connection.uuid]?.untrackConnection(connection)
    _groupsByConnection[connection.uuid] = nil
  }

  /**
  Iterate over all direct connections on a given group's `ownerBlock` and find the one that is
  closest to a valid connection on another block.

  - Parameter group: The group whose `ownerBlock`'s direct connections to search
  - Parameter maxRadius: How far out to search for compatible connections, specified as a Workspace
  coordinate system unit
  - Returns: A connection pair where the `pair.moving` connection is one on the given block and the
  `pair.target` connection is the closest compatible connection. Nil is returned if no suitable
  connection pair could be found.
  */
  public func findBestConnectionForGroup(_ group: ConnectionManager.Group, maxRadius: CGFloat)
    -> ConnectionPair? {
      guard let block = group.ownerBlock else {
        return nil
      }

      // Find the connection that is closest to any direct connection on the block.
      var candidate: ConnectionPair?
      var radius = maxRadius

      for blockConnection in block.directConnections {
        if let compatibleConnection =
          closestConnection(blockConnection, maxRadius: radius, ignoreGroup: group)
        {
          candidate = (
            moving: blockConnection,
            target: compatibleConnection.0,
            fromConnectionManagerGroup: compatibleConnection.1)
          radius = blockConnection.distanceFromConnection(compatibleConnection.0)
        }
      }

      return candidate
  }

  /**
  Finds all compatible connections (including shadow connections) within the given radius, that are
  not currently being dragged. This function is used for bumping so type checking does not apply.

  - Parameter connection: The base connection for the search.
  - Parameter maxRadius: How far out to search for compatible connections, specified as a Workspace
  coordinate system unit
  - Returns: A list of all nearby compatible connections.
  */
  public func stationaryNeighboursFor(connection: Connection, maxRadius: CGFloat)
    -> [Connection]
  {
    return _groups.filter({ $0.dragMode == false })
      .flatMap({ $0.neighboursFor(connection: connection, maxRadius: maxRadius)})
  }

  // MARK: - Internal - For testing only

  /**
  Deletes a `ConnectionManager.Group` from the manager.

  - Parameter group: The group to delete
  - Throws:
  `BlocklyError`: Thrown with .ConnectionManagerError if (`group` == `mainGroup`) or if `group` is
  not empty.
  */
  internal func deleteGroup(_ group: ConnectionManager.Group) throws {
    if group == mainGroup {
      throw BlocklyError(.connectionManagerError, "Cannot remove the mainGroup")
    } else if !group.allConnections.isEmpty {
      throw BlocklyError(.connectionManagerError, "Cannot delete non-empty group")
    }

    _groups.remove(group)
  }

  /**
  Find the closest compatible connection to this connection.

  - Parameter connection: The base connection for the search.
  - Parameter maxRadius: How far out to search for compatible connections.
  - Parameter ignoreGroup: Optional group to ignore when looking for compatible connections.
  - Returns: The closest compatible connection and the connection group it was found in.
  */
  internal func closestConnection(
    _ connection: Connection, maxRadius: CGFloat, ignoreGroup: ConnectionManager.Group?)
    -> (Connection, ConnectionManager.Group)?
  {
    var radius = maxRadius
    var candidate: (Connection, ConnectionManager.Group)? = nil

    for group in _groups {
      if group == ignoreGroup {
        continue
      }

      if let compatibleConnection = group.closestConnection(connection, maxRadius: radius,
                                                            validator: connectionValidator)
      {
        candidate = (compatibleConnection, group)
        radius = connection.distanceFromConnection(compatibleConnection)
      }
    }

    return candidate
  }
}

// MARK: - Class - ConnectionManager.Group

extension ConnectionManager {
  /**
  Manages a specific set of `Connection` instances.
  */
  @objc(BKYConnectionManagerGroup)
  public final class Group: NSObject, ConnectionPositionDelegate {

    // MARK: - Properties
    fileprivate weak var ownerBlock: Block?

    fileprivate let _previousConnections = YSortedList()
    fileprivate let _nextConnections = YSortedList()
    fileprivate let _inputConnections = YSortedList()
    fileprivate let _outputConnections = YSortedList()

    fileprivate let _matchingLists: [YSortedList]
    fileprivate let _oppositeLists: [YSortedList]

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

    fileprivate init(ownerBlock: Block?) {
      self.ownerBlock = ownerBlock

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
    internal func trackConnection(_ connection: Connection) {
      addConnection(connection)
      connection.positionDelegate = self
    }

    /**
    Removes this connection from the group and stops listening for changes to its position.

    - Parameter connection: The connection to remove.
    */
    internal func untrackConnection(_ connection: Connection) {
      removeConnection(connection)
      if connection.positionDelegate === self {
        connection.positionDelegate = nil
      }
    }

    /**
    Find all compatible connections (including shadow connections) within the given radius. 
    This function is used for bumping so type checking does not apply.

    - Parameter connection: The base connection for the search.
    - Parameter maxRadius: How far out to search for compatible connections.
    - Returns: A list of all nearby compatible connections.
    */
    internal func neighboursFor(connection: Connection, maxRadius: CGFloat)
      -> [Connection] {
        let compatibleList = _oppositeLists[connection.type.rawValue]
        return compatibleList.neighboursFor(connection: connection, maxRadius: maxRadius)
    }

    /**
    Find the closest compatible connection to this connection.

    - Parameter connection: The base connection for the search.
    - Parameter maxRadius: How far out to search for compatible connections.
    - Parameter validator: The ConnectionValidator to evaluate connectability.
    - Returns: The closest compatible connection.
    */
    internal func closestConnection(_ connection: Connection, maxRadius: CGFloat, validator:
                                    ConnectionValidator) -> Connection? {
      if connection.connected {
        // Don't offer to connect when already connected.
        return nil
      }
      let compatibleList = _oppositeLists[connection.type.rawValue]
      return compatibleList.searchForClosestValidConnectionTo(connection, maxRadius: maxRadius,
                                                              validator: validator)
    }

    internal func connectionsForType(_ type: Connection.ConnectionType) -> YSortedList {
      return _matchingLists[type.rawValue]
    }

    /**
    Moves connections that are being tracked by this group to another group.

    - Parameter toGroup: The new group
    */
    internal func transferConnectionsToGroup(_ toGroup: Group) {
      for i in 0 ..< _matchingLists.count {
        let fromConnectionList = _matchingLists[i]
        let toConnectionList = toGroup._matchingLists[i]

        // Set the position delegate to the new group
        let affectedConnections = fromConnectionList._connections
        for connection in affectedConnections {
          connection.positionDelegate = toGroup
        }

        // And now transfer the connections over to the corresponding list in the new group
        fromConnectionList.transferConnectionsToList(toConnectionList)
      }
    }

    // MARK: - Private

    /**
    Figure out which list the connection belongs to and insert it.

    - Parameter connection: The connection to add.
    */
    fileprivate func addConnection(_ connection: Connection) {
      _matchingLists[connection.type.rawValue].addConnection(connection)
    }

    /**
    Remove a connection from the list that handles connections of its type.

    - Parameter connection: The connection to remove.
    */
    fileprivate func removeConnection(_ connection: Connection) {
      _matchingLists[connection.type.rawValue].removeConnection(connection)
    }

    // MARK: - ConnectionPositionDelegate

    public func willChangePositionFor(connection: Connection) {
      if dragMode {
        return
      }
      // Position will change, temporarily remove it. It will be re-added in
      // didChangePositionFor(connection:).
      removeConnection(connection)
    }

    public func didChangePositionFor(connection: Connection) {
      if dragMode {
        return
      }
      // This call was immediately preceded by willChangePositionFor(connection:)
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
  internal final class YSortedList {
    // MARK: - Properties

    fileprivate var _connections = [Connection]()

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

    - Parameter connection: The connection to insert.
    */
    internal func addConnection(_ connection: Connection) {
      _connections.insert(connection, at: findPositionFor(connection: connection))
    }

    /**
    Remove the given connection from this list.

    -Parameter connection: The connection to remove.
    */
    internal func removeConnection(_ connection: Connection) {
      if let removalIndex = findConnection(connection) {
        _connections.remove(at: removalIndex)
      }
    }

    internal func removeAllConnections() {
      _connections.removeAll()
    }

    internal func isInYRangeForIndex(_ index: Int, _ baseY: CGFloat, _ maxRadius: CGFloat) -> Bool {
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
    internal func findConnection(_ connection: Connection) -> Int? {
      if _connections.isEmpty {
        return nil
      }

      // Should have the right y position.
      let bestGuess = findPositionFor(connection: connection)
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
        pointerMin -= 1
      }
      while (pointerMax < _connections.count && _connections[pointerMax].position.y == yPos) {
        if _connections[pointerMax] == connection {
          return pointerMax
        }
        pointerMax += 1
      }
      return nil
    }

    /**
    Finds a candidate position for inserting this connection into the given list.
    This will be in the correct y order but makes no guarantees about ordering in the x axis.

    - Parameter connection: The connection to insert.
    - Returns: The candidate index.
    */
    internal func findPositionFor(connection: Connection) -> Int {
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

    internal func searchForClosestValidConnectionTo(_ connection: Connection, maxRadius: CGFloat,
                                                    validator: ConnectionValidator)
      -> Connection? {
        // Don't bother.
        if _connections.isEmpty {
          return nil
        }

        let baseY = connection.position.y
        // findPositionFor(connection:) finds an index for insertion, which is always after any
        // block with the same y index.  We want to search both forward and back, so search
        // on both sides of the index.
        let closestIndex = findPositionFor(connection: connection)

        var bestConnection: Connection?
        var bestRadius = maxRadius

        // Walk forward and back on the y axis looking for the closest x,y point.
        var pointerMin = closestIndex - 1
        while (pointerMin >= 0 && isInYRangeForIndex(pointerMin, baseY, maxRadius)) {
          let temp = _connections[pointerMin]
          let distance = connection.distanceFromConnection(temp)
          if distance <= bestRadius && validator.canConnect(connection, toConnection: temp) {
            bestConnection = temp
            bestRadius = temp.distanceFromConnection(connection)
          }
          pointerMin -= 1
        }

        var pointerMax = closestIndex
        while (pointerMax < _connections.count &&
          isInYRangeForIndex(pointerMax, baseY, maxRadius)) {
            let temp = _connections[pointerMax]
            let distance = connection.distanceFromConnection(temp)
            if distance <= bestRadius && validator.canConnect(connection, toConnection: temp) {
              bestConnection = temp
              bestRadius = temp.distanceFromConnection(connection)
            }
            pointerMax += 1
        }
        return bestConnection
    }

    internal func neighboursFor(connection: Connection, maxRadius: CGFloat)
      -> [Connection] {
        var neighbours = [Connection]()
        // Don't bother.
        if _connections.isEmpty {
          return neighbours
        }

        let baseY = connection.position.y
        // findPositionFor(connection:) finds an index for insertion, which is always after any
        // block with the same y index.  We want to search both forward and back, so search
        // on both sides of the index.
        let closestIndex = findPositionFor(connection: connection)

        // Walk forward and back on the y axis looking for the closest x,y point.
        // If both connections are connected, that's probably fine.  But if
        // either one of them is unconnected, then there could be confusion.
        var pointerMin = closestIndex - 1
        while (pointerMin >= 0 && isInYRangeForIndex(pointerMin, baseY, maxRadius)) {
          let temp = _connections[pointerMin]
          let connectReason = connection.canConnectWithReasonTo(temp)
          // We use Connection rather than ConnectionValidator here, because neighbors are
          // used to check for bumping like blocks away from each other. Two blocks might
          // be unable to connect, but we want to make sure their blocks don't obscure one
          // another, so neighbors returns anything that could connect.
          let couldConnect = connectReason.intersectsWith(.CanConnect) ||
                             connectReason.intersectsWith(.ReasonMustDisconnect)
          if ((!connection.connected || !temp.connected) &&
            connection.distanceFromConnection(temp) <= maxRadius &&
            couldConnect)
          {
            neighbours.append(temp)
          }
          pointerMin -= 1
        }

        var pointerMax = closestIndex
        while (pointerMax < _connections.count &&
          isInYRangeForIndex(pointerMax, baseY, maxRadius)) {
            let temp = _connections[pointerMax]
            let connectReason = connection.canConnectWithReasonTo(temp)
            let couldConnect = connectReason.intersectsWith(.CanConnect) ||
              connectReason.intersectsWith(.ReasonMustDisconnect)
            if ((!connection.connected || !temp.connected) &&
              connection.distanceFromConnection(temp) <= maxRadius &&
              couldConnect)
            {
              neighbours.append(temp)
            }
            pointerMax += 1
        }
        return neighbours
    }

    internal func contains(_ connection: Connection) -> Bool {
      return findConnection(connection) != nil
    }

    internal func transferConnectionsToList(_ toList: YSortedList) {
      // Transfer connections using merge sort
      var insertionIndex = 0

      for connection in _connections {
        // Find the next insertion index
        while insertionIndex < toList.count &&
          toList[insertionIndex].position.y < connection.position.y  {
            insertionIndex += 1
        }

        // Insert the connection and increment the insertion index
        toList._connections.insert(connection, at: insertionIndex)
        insertionIndex += 1
      }

      // Finally, remove all connections from this list
      removeAllConnections()
    }
  }
}
