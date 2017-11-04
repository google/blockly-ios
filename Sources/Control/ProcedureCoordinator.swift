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

import Foundation

// MARK: - ProcedureCoordinator Class

/**
 Coordinates the logic of all procedure blocks inside a `WorkbenchViewController`.
 */
@objc(BKYProcedureCoordinator)
@objcMembers public class ProcedureCoordinator: NSObject {

  // MARK: - Properties

  /// Block name for the procedure definition with no return value
  public static let BLOCK_DEFINITION_NO_RETURN = "procedures_defnoreturn"
  /// Block name for the procedure definition with a return value
  public static let BLOCK_DEFINITION_RETURN = "procedures_defreturn"
  /// Block name for the procedure caller with no return value
  public static let BLOCK_CALLER_NO_RETURN = "procedures_callnoreturn"
  /// Block name for the procedure caller with a return value
  public static let BLOCK_CALLER_RETURN = "procedures_callreturn"
  /// Block name for the "if-return" block.
  public static let BLOCK_IF_RETURN = "procedures_ifreturn"

  /// The workbench that this coordinator is synchronized with
  public private(set) weak var workbench: WorkbenchViewController? {
    didSet {
      oldValue?.variableNameManager.listeners.remove(self)
      oldValue?.workspace?.listeners.remove(self)

      workbench?.workspace?.listeners.add(self)
      workbench?.variableNameManager.listeners.add(self)
    }
  }

  /// Manager responsible for keeping track of all procedure names under the workbench
  fileprivate let procedureNameManager = NameManager()

  /// Manager responsible for keeping track of all variables under the workbench
  fileprivate var variableNameManager: NameManager? {
    return workbench?.variableNameManager
  }

  /// Set of all procedure definition blocks in the main workspace.
  fileprivate var definitionBlocks = WeakSet<Block>()

  /// Set of all procedure caller blocks in both the main workspace and toolbox.
  fileprivate var callerBlocks = WeakSet<Block>()

  /// Set of all if-return blocks in the main workspace.
  fileprivate var ifReturnBlocks = WeakSet<Block>()

  /// Map of block uuid's to their procedure definition name. This is used when a procedure
  /// definition block is renamed and the coordinator needs to rename all existing caller blocks
  /// that used the old procedure name (which is being kept track of here).
  fileprivate var blockProcedureNames = [String: String]()

  // MARK: - Initializers

  public override init() {
    super.init()

    EventManager.shared.addListener(self)
  }

  deinit {
    EventManager.shared.removeListener(self)
  }

  // MARK: - Workbench

  /**
   Synchronizes this coordinator with a workbench so that all procedure definition/caller blocks
   in the main workspace are in a proper state.

   Here are some examples of what can be defined as a "proper" state:
   - Each procedure definition block in the workspace is unique.
   - All procedure definition blocks defined in the workspace must have an associated caller block
   in the toolbox.
   - No procedure caller block exists in the workspace without an associated definition block.
   - All parameters used in procedure definition blocks are created as variables inside
   `workbench.variableNameManager`.

   - parameter workbench: The `WorkbenchViewController` to synchronize with. This value is then
   set to `self.workbench` after this method is called.
   - note: `workbench` must have its toolbox and workspace loaded, or else this method does nothing
   but assign `workbench` to `self.workbench`.
   */
  public func syncWithWorkbench(_ workbench: WorkbenchViewController?) {
    // Remove cache of definition and caller blocks
    definitionBlocks.removeAll()
    callerBlocks.removeAll()
    ifReturnBlocks.removeAll()
    blockProcedureNames.removeAll()

    // Set to the new workbench
    self.workbench = workbench

    if let workspace = workbench?.workspace,
      workbench?.toolbox != nil
    {
      // Track all relevant procedure blocks in the workspace
      for (_, block) in workspace.allBlocks {
        if block.isProcedureDefinition {
          trackProcedureDefinitionBlock(block)
        } else if block.isProcedureCaller {
          trackProcedureCallerBlock(block)
        } else if block.isIfReturn {
          trackIfReturnBlock(block, validate: true)
        }
      }

      // For every caller block, update its parameters to match its corresponding definition block's
      // parameters or auto-create a definition block if none exists
      for callerBlock in callerBlocks {
        if let definitionBlock = procedureDefinitionBlock(forCallerBlock: callerBlock) {
          callerBlock.procedureParameters = definitionBlock.procedureParameters
        } else {
          createProcedureDefinitionBlock(fromCallerBlock: callerBlock)
        }
      }
    }
  }

  // MARK: - Procedure Definition Methods

  fileprivate func trackProcedureDefinitionBlock(_ definitionBlock: Block) {
    guard definitionBlock.isProcedureDefinition else {
      return
    }

    // Add to set of definition blocks
    definitionBlocks.add(definitionBlock)

    // Assign a unique procedure name to the block and add it to the list of known procedure names
    let uniqueProcedureName =
      procedureNameManager.generateUniqueName(definitionBlock.procedureName, addToList: true)
    definitionBlock.procedureName = uniqueProcedureName

    // Track block's current procedure name
    blockProcedureNames[definitionBlock.uuid] = uniqueProcedureName

    // Upsert variables from block to NameManager
    upsertVariables(fromDefinitionBlock: definitionBlock)

    // Create an associated caller procedure to the toolbox
    do {
      if let toolboxProcedureLayoutCoordinator = firstToolboxProcedureLayoutCoordinator(),
        let blockFactory = toolboxProcedureLayoutCoordinator.blockFactory
      {
        let callerBlock =
          try blockFactory.makeBlock(name: definitionBlock.associatedCallerBlockName)
        callerBlock.procedureName = definitionBlock.procedureName
        callerBlock.procedureParameters = definitionBlock.procedureParameters
        try toolboxProcedureLayoutCoordinator.addBlockTree(callerBlock)

        // Track this new block as a caller block so it can be updated if the definition changes
        callerBlocks.add(callerBlock)
      }
    } catch let error {
      bky_assertionFailure("Could not add block to toolbox: \(error)")
    }
  }

  fileprivate func untrackProcedureDefinitionBlock(_ definitionBlock: Block) {
    guard definitionBlock.isProcedureDefinition else {
      return
    }

    // Remove all caller blocks that use this definition block
    removeProcedureCallerBlocks(forDefinitionBlock: definitionBlock)

    // Remove from set of definition blocks
    definitionBlocks.remove(definitionBlock)

    // Remove block procedure mapping
    blockProcedureNames[definitionBlock.uuid] = nil

    // Remove procedure name from manager
    procedureNameManager.removeName(definitionBlock.procedureName)
  }

  fileprivate func upsertVariables(fromDefinitionBlock block: Block) {
    guard block.isProcedureDefinition,
      let variableNameManager = self.variableNameManager else {
      return
    }

    for parameter in block.procedureParameters {
      if !variableNameManager.containsName(parameter.name) {
        // Add name to variable manager
        do {
          try variableNameManager.addName(parameter.name)
        } catch let error {
          bky_assertionFailure("Could not add parameter '\(parameter)' as variable: \(error)")
        }
      } else {
        // Update the display name of the parameter
        variableNameManager.renameDisplayName(parameter.name)
      }
    }
  }

  fileprivate func createProcedureDefinitionBlock(fromCallerBlock callerBlock: Block) {
    guard let blockFactory = firstToolboxProcedureLayoutCoordinator()?.blockFactory else {
      return
    }

    do {
      let definitionBlock =
        try blockFactory.makeBlock(name: callerBlock.associatedDefinitionBlockName)

      // For now, set the definition block's procedure name to match the caller block's name.
      // If it's a duplicate of something else already in the workspace, it will automatically
      // get renamed when `trackProcedureDefinitionBlock(...)` is ultimately called.
      definitionBlock.procedureName = callerBlock.procedureName
      definitionBlock.procedureParameters = callerBlock.procedureParameters
      definitionBlock.position = callerBlock.position + WorkspacePoint(x: 20, y: 20)

      try workbench?.workspaceViewController.workspaceLayoutCoordinator?.addBlockTree(
        definitionBlock)

      // After the definition block has been added to the workspace, it should have a unique
      // name now. Rename the caller's procedure name to match it.
      callerBlock.procedureName = definitionBlock.procedureName
    } catch let error {
      bky_assertionFailure("Could not create definition block for caller: \(error)")
    }
  }

  fileprivate func renameProcedureDefinitionBlock(
    _ block: Block, from oldName: String, to newName: String)
  {
    guard block.isProcedureDefinition else {
      return
    }

    // Remove old procedure name
    procedureNameManager.removeName(oldName)

    // Make sure the new name is unique and add it to the list of procedure names
    let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    let uniqueName = procedureNameManager.generateUniqueName(trimmedName, addToList: true)

    // Assign this unique name back to the block
    blockProcedureNames[block.uuid] = uniqueName
    block.procedureName = uniqueName

    // Rename all caller blocks in workspace/toolbox
    updateProcedureCallers(oldName: oldName, newName: uniqueName,
                           parameters: block.procedureParameters)
  }

  fileprivate func procedureDefinitionBlock(forCallerBlock callerBlock: Block) -> Block? {
    return definitionBlocks.first(where: { definitionBlock($0, matchesCallerBlock: callerBlock) })
  }

  fileprivate func definitionBlock(
    _ definitionBlock: Block, matchesCallerBlock callerBlock: Block) -> Bool {
    return
      definitionBlock.isProcedureDefinition &&
      callerBlock.isProcedureCaller &&
      definitionBlock.associatedCallerBlockName == callerBlock.name &&
      procedureNameManager.namesAreEqual(
        definitionBlock.procedureName, callerBlock.procedureName) &&
      definitionBlock.procedureParameters.map({ $0.name }) ==
        callerBlock.procedureParameters.map({ $0.name })
  }

  // MARK: - Procedure Caller Methods

  fileprivate func trackProcedureCallerBlock(_ callerBlock: Block) {
    guard callerBlock.isProcedureCaller else {
      return
    }

    // Add to set of caller blocks
    callerBlocks.add(callerBlock)

    if let definitionBlock = procedureDefinitionBlock(forCallerBlock: callerBlock) {
      // Make sure the procedure caller block has the exact same parameters as the definition block,
      // so its parameters' connections are properly preserved on parameter renames/re-orderings
      callerBlock.procedureParameters = definitionBlock.procedureParameters
    }
  }

  fileprivate func untrackProcedureCallerBlock(_ callerBlock: Block) {
    guard callerBlock.isProcedureCaller else {
      return
    }

    callerBlocks.remove(callerBlock)
  }

  fileprivate func removeProcedureCallerBlocks(forDefinitionBlock definitionBlock: Block) {
    guard definitionBlock.isProcedureDefinition else {
      return
    }

    do {
      for callerBlock in callerBlocks {
        if procedureNameManager.namesAreEqual(
          callerBlock.procedureName, definitionBlock.procedureName)
        {
          if let toolboxCoordinator = firstToolboxProcedureLayoutCoordinator(),
            toolboxCoordinator.workspaceLayout.workspace.containsBlock(callerBlock)
          {
            // Remove from toolbox
            try toolboxCoordinator.removeBlockTree(callerBlock)
          } else if let workspaceCoordinator =
            workbench?.workspaceViewController.workspaceLayoutCoordinator,
            workspaceCoordinator.workspaceLayout.workspace.containsBlock(callerBlock)
          {
            // Remove from main workspace
            try workspaceCoordinator.removeBlockTree(callerBlock)
          }
        }
      }
    } catch let error {
      bky_assertionFailure("Could not remove caller blocks from toolbox/workspace: \(error)")
    }
  }

  fileprivate func updateProcedureCallers(
    oldName: String, newName: String, parameters: [ProcedureParameter])
  {
    for callerBlock in callerBlocks {
      if procedureNameManager.namesAreEqual(callerBlock.procedureName, oldName),
        let mutatorCallerLayout = callerBlock.layout?.mutatorLayout as? MutatorProcedureCallerLayout
      {
        // NOTE: mutatorLayout is used here since it will preserve connections for existing inputs
        // if the parameters have been reordered.
        mutatorCallerLayout.preserveCurrentInputConnections()
        mutatorCallerLayout.procedureName = newName
        mutatorCallerLayout.parameters = parameters

        do {
          try mutatorCallerLayout.performMutation()

          if let blockLayout = mutatorCallerLayout.mutator.block?.layout {
            Layout.animate {
              mutatorCallerLayout.layoutCoordinator?.blockBumper
                .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
            }
          }
        } catch let error {
          bky_assertionFailure(
            "Could not update procedure caller to match procedure definition: \(error)")
        }
      }
    }
  }

  // MARK: - If-Return Methods

  fileprivate func trackIfReturnBlock(_ block: Block, validate: Bool) {
    guard block.isIfReturn else { return }

    ifReturnBlocks.add(block)

    if validate {
      validateIfReturnBlock(block)
    }
  }

  fileprivate func untrackIfReturnBlock(_ block: Block) {
    guard block.isIfReturn else { return }

    ifReturnBlocks.remove(block)
  }

  fileprivate func validateIfReturnBlock(_ block: Block) {
    // We only care about if-return blocks that are in the main workspace
    guard block.isIfReturn,
      let blockLayout = block.layout,
      let rootBlock = blockLayout.rootBlockGroupLayout?.blockLayouts[0].block,
      let workspace = workbench?.workspace,
      workspace.containsBlock(block) else {
      return
    }

    // Disable this if-return block if it isn't connected to a procedure definition block.
    blockLayout.disabled =
      rootBlock.name != ProcedureCoordinator.BLOCK_DEFINITION_NO_RETURN &&
      rootBlock.name != ProcedureCoordinator.BLOCK_DEFINITION_RETURN
  }

  // MARK: - Helpers

  fileprivate func firstToolboxProcedureLayoutCoordinator() -> WorkspaceLayoutCoordinator? {
    if let toolboxLayout = workbench?.toolboxCategoryViewController.toolboxLayout {
      for (i, category) in toolboxLayout.toolbox.categories.enumerated() {
        if category.categoryType == .procedure {
          return toolboxLayout.categoryLayoutCoordinators[i]
        }
      }
    }

    return nil
  }
}

extension ProcedureCoordinator: WorkspaceListener {
  // MARK: - WorkspaceListener Implementation

  public func workspace(_ workspace: Workspace, willAddBlockTrees blockTrees: [Block]) {
    // Look at all block trees that are being added to see if any caller blocks need to have 
    // definitions auto-created for them.
    let definitionBlocks = blockTrees.filter({ $0.isProcedureDefinition })
    let callerBlocks =
      blockTrees.flatMap({ $0.allBlocksForTree() }).filter({ $0.isProcedureCaller })

    for callerBlock in callerBlocks {
      if procedureDefinitionBlock(forCallerBlock: callerBlock) == nil &&
        !definitionBlocks.contains(where: { definitionBlock($0, matchesCallerBlock: callerBlock) })
      {
        // No procedure block exists for this caller in the workspace.
        // Automatically create it first before adding in the caller block to the workspace. This
        // makes sure that events are ordered in such a way that they can be properly undone.
        createProcedureDefinitionBlock(fromCallerBlock: callerBlock)
      }
    }
  }

  public func workspace(_ workspace: Workspace, didAddBlockTrees blockTrees: [Block]) {
    for block in blockTrees.flatMap({ $0.allBlocksForTree() }) {
      if block.isProcedureDefinition {
        trackProcedureDefinitionBlock(block)
      } else if block.isProcedureCaller {
        trackProcedureCallerBlock(block)
      } else if block.isIfReturn {
        // Don't immediately validate the block, since it's usually an orphan at this point,
        // and will cause the block to appear disabled. A create/move event will occur
        // after this add so it will be validated shortly thereafter.
        trackIfReturnBlock(block, validate: false)
      }
    }
  }

  public func workspace(_ workspace: Workspace, willRemoveBlockTrees blockTrees: [Block]) {
    for block in blockTrees {
      if block.isProcedureDefinition {
        // Remove all caller blocks for the definition before removing the definition block. If
        // the caller blocks are removed after the definition block, then it causes problems undoing
        // the event stack where a caller block is recreated without any definition block. Reversing
        // the order fixes this problem.
        removeProcedureCallerBlocks(forDefinitionBlock: block)
      }
    }
  }

  public func workspace(_ workspace: Workspace, didRemoveBlockTrees blockTrees: [Block]) {
    for block in blockTrees.flatMap({ $0.allBlocksForTree() }) {
      if block.isProcedureDefinition {
        untrackProcedureDefinitionBlock(block)
      } else if block.isProcedureCaller {
        untrackProcedureCallerBlock(block)
      } else if block.isIfReturn {
        untrackIfReturnBlock(block)
      }
    }
  }
}

extension ProcedureCoordinator: EventManagerListener {

  public func eventManager(_ eventManager: EventManager, didFireEvent event: BlocklyEvent) {
    // Try to handle the event. The first method that returns `true` means it's been handled and
    // we can skip the rest of the checks.
    if let fieldEvent = event as? BlocklyEvent.Change,
      fieldEvent.element == BlocklyEvent.Change.elementField {
      processFieldChangeEvent(fieldEvent)
    } else if let mutationEvent = event as? BlocklyEvent.Change,
      mutationEvent.element == BlocklyEvent.Change.elementMutate {
      processMutationChangeEvent(mutationEvent)
    } else if let createEvent = event as? BlocklyEvent.Create {
      processCreateEvent(createEvent)
    } else if let moveEvent = event as? BlocklyEvent.Move {
      processMoveEvent(moveEvent)
    }
  }

  private func processFieldChangeEvent(_ fieldEvent: BlocklyEvent.Change) {
    guard fieldEvent.element == BlocklyEvent.Change.elementField,
      fieldEvent.fieldName == "NAME",
      fieldEvent.workspaceID == workbench?.workspace?.uuid,
      let blockID = fieldEvent.blockID,
      let block = workbench?.workspace?.allBlocks[blockID],
      block.isProcedureDefinition,
      let oldProcedureName = blockProcedureNames[block.uuid],
      let newProcedureName = block.procedureDefinitionNameInput?.text,
      !procedureNameManager.namesAreEqual(oldProcedureName, newProcedureName) else {
      return
    }

    // Add additional events to the existing event group
    EventManager.shared.groupAndFireEvents(groupID: fieldEvent.groupID) {
      if newProcedureName.trimmingCharacters(in: .whitespaces).isEmpty {
        // Procedure names shouldn't be empty. Put it back to what it was
        // originally.
        // Note: The field layout is used to reset the procedure name here so that a
        // `BlocklyEvent.Change` is automatically created for this change.
        try? block.procedureDefinitionNameInput?.layout?.setValue(
          fromSerializedText: oldProcedureName)
      } else {
        // Procedure name has changed for definition block. Rename it.
        renameProcedureDefinitionBlock(block, from: oldProcedureName, to: newProcedureName)
      }
    }
  }

  private func processMutationChangeEvent(_ mutationEvent: BlocklyEvent.Change) {
    guard mutationEvent.element == BlocklyEvent.Change.elementMutate,
      mutationEvent.workspaceID == workbench?.workspace?.uuid,
      let blockID = mutationEvent.blockID,
      let block = workbench?.workspace?.allBlocks[blockID],
      block.isProcedureDefinition else {
      return
    }

    // Add additional events to the existing event group
    EventManager.shared.groupAndFireEvents(groupID: mutationEvent.groupID) {
      // A procedure definition block inside the main workspace has been mutated.
      // Update the procedure callers and upsert the variables from this block.
      updateProcedureCallers(oldName: block.procedureName, newName: block.procedureName,
                             parameters: block.procedureParameters)
      upsertVariables(fromDefinitionBlock: block)
    }
  }

  private func processCreateEvent(_ createEvent: BlocklyEvent.Create) {
    // We only care about create events that happen in the main workspace.
    guard let workspace = workbench?.workspace,
      workspace.uuid == createEvent.workspaceID else {
      return
    }

    // Validate any if-return blocks that were created from this event.
    EventManager.shared.groupAndFireEvents(groupID: createEvent.groupID) {
      for blockID in createEvent.blockIDs {
        if let block = workspace.allBlocks[blockID], block.isIfReturn {
          validateIfReturnBlock(block)
        }
      }
    }
  }

  private func processMoveEvent(_ moveEvent: BlocklyEvent.Move) {
    // We only care about move events that happen in the main workspace.
    guard workbench?.workspace?.uuid == moveEvent.workspaceID else { return }

    // Something has been moved in the workspace, which means an if-return block may have changed
    // grandparents. Re-validate all if-return blocks (this is faster than traversing the
    // block tree(s) affected by the move event, since the total number of if-return blocks is
    // likely to be very few).
    EventManager.shared.groupAndFireEvents(groupID: moveEvent.groupID) {
      for block in self.ifReturnBlocks {
        validateIfReturnBlock(block)
      }
    }
  }
}

extension ProcedureCoordinator: NameManagerListener {
  // MARK: - NameManagerListener Implementation

  public func nameManager(_ nameManager: NameManager, shouldRemoveName name: String) -> Bool {
    if nameManager == workbench?.variableNameManager {
      // If any of the procedures use the variables, disable this action
      for block in definitionBlocks {
        for parameter in block.procedureParameters {
          if nameManager.namesAreEqual(name, parameter.name) {
            // Found a parameter using this name
            let errorText = message(forKey: "BKY_IOS_ERROR")
            let description = message(forKey: "BKY_CANNOT_DELETE_VARIABLE_PROCEDURE")
              .replacingOccurrences(of: "%1", with: name)
              .replacingOccurrences(of: "%2", with: block.procedureName)
            let okText = message(forKey: "BKY_IOS_OK")

            let alert = UIAlertView(title: errorText, message: description, delegate: nil,
                                    cancelButtonTitle: nil, otherButtonTitles: okText)
            alert.show()
            return false
          }
        }
      }
    }
    return true
  }

  public func nameManager(
    _ nameManager: NameManager, didRenameName oldName: String, toName newName: String)
  {
    if nameManager == workbench?.variableNameManager {
      // Update all procedure definitions that use this variable
      for block in definitionBlocks {
        // NOTE: mutatorLayout is used here since it will generate a notification after
        // the mutation has been performed. When this notification fires, `ProcedureCoordinator`
        // listens to it and updates any associated caller blocks in the workspace to match
        // the new definition.
        if let mutatorLayout = block.layout?.mutatorLayout as? MutatorProcedureDefinitionLayout {
          var updateMutator = false
          for (i, parameter) in mutatorLayout.parameters.enumerated() {
            if nameManager.namesAreEqual(oldName, parameter.name) {
              mutatorLayout.parameters[i].name = newName
              updateMutator = true
            }
          }

          if updateMutator {
            do {
              try mutatorLayout.performMutation()

              if let blockLayout = mutatorLayout.mutator.block?.layout {
                Layout.animate {
                  mutatorLayout.layoutCoordinator?.blockBumper
                    .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
                }
              }
            } catch let error {
              bky_assertionFailure("Could not update mutator parameter variables: \(error)")
            }
          }
        }
      }
    }
  }
}

// MARK: - Block Extension Methods

fileprivate extension Block {
  var isProcedureDefinition: Bool {
    return name == ProcedureCoordinator.BLOCK_DEFINITION_NO_RETURN ||
      name == ProcedureCoordinator.BLOCK_DEFINITION_RETURN
  }

  var isProcedureCaller: Bool {
    return name == ProcedureCoordinator.BLOCK_CALLER_NO_RETURN ||
      name == ProcedureCoordinator.BLOCK_CALLER_RETURN
  }

  var isIfReturn: Bool {
    return name == ProcedureCoordinator.BLOCK_IF_RETURN
  }

  var procedureDefinitionNameInput: FieldInput? {
    return isProcedureDefinition ? firstField(withName: "NAME") as? FieldInput : nil
  }

  var mutatorProcedureDefinition: MutatorProcedureDefinition? {
    return mutator as? MutatorProcedureDefinition
  }

  var mutatorProcedureCaller: MutatorProcedureCaller? {
    return mutator as? MutatorProcedureCaller
  }

  var procedureName: String {
    get {
      if isProcedureDefinition {
        return procedureDefinitionNameInput?.text ?? ""
      } else if isProcedureCaller {
        return mutatorProcedureCaller?.procedureName ?? ""
      } else {
        return ""
      }
    }
    set {
      if isProcedureDefinition {
        procedureDefinitionNameInput?.text = newValue
      } else if isProcedureCaller {
        mutatorProcedureCaller?.procedureName = newValue
        try? mutatorProcedureCaller?.mutateBlock()
      }
    }
  }

  var procedureParameters: [ProcedureParameter] {
    get {
      return mutatorProcedureCaller?.parameters ?? mutatorProcedureDefinition?.parameters ?? []
    }
    set {
      if isProcedureDefinition {
        mutatorProcedureDefinition?.parameters = newValue
        try? mutatorProcedureDefinition?.mutateBlock()
      } else if isProcedureCaller {
        mutatorProcedureCaller?.parameters = newValue
        try? mutatorProcedureCaller?.mutateBlock()
      }
    }
  }

  var associatedCallerBlockName: String {
    switch name {
      case ProcedureCoordinator.BLOCK_DEFINITION_NO_RETURN:
        return ProcedureCoordinator.BLOCK_CALLER_NO_RETURN
      case ProcedureCoordinator.BLOCK_DEFINITION_RETURN:
        return ProcedureCoordinator.BLOCK_CALLER_RETURN
      default:
        return ""
    }
  }

  var associatedDefinitionBlockName: String {
    switch name {
      case ProcedureCoordinator.BLOCK_CALLER_NO_RETURN:
        return ProcedureCoordinator.BLOCK_DEFINITION_NO_RETURN
      case ProcedureCoordinator.BLOCK_CALLER_RETURN:
        return ProcedureCoordinator.BLOCK_DEFINITION_RETURN
      default:
        return ""
    }
  }
}
