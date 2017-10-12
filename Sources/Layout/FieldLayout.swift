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
Protocol for measuring the size of a `Layout` when it is rendered.
*/
@objc(BKYFieldLayoutMeasurer)
public protocol FieldLayoutMeasurer {
  /**
  Measures and returns the amount of space needed to render a `FieldLayout`, in a `UIView`.

  - parameter layout: The layout to measure
  - parameter scale: The current scale of the layout's `workspaceLayout`.
  - returns: The amount of space needed, in UIView coordinates.
  */
  static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize
}

/**
Abstract class for a `Field`-based `Layout`.
*/
@objc(BKYFieldLayout)
@objcMembers open class FieldLayout: Layout {
  // MARK: - Properties

  /// Object responsible for measuring the layout of this object.
  open var measurer: FieldLayoutMeasurer.Type

  /// The target field to layout
  public final let field: Field

  /// Flag determining if user interaction should be enabled for the corresponding view
  open var userInteractionEnabled: Bool {
    return field.editable
  }

  // MARK: - Initializers

  /**
   Initializes the field layout.

   - parameter field: The `Field` model object to create a layout for.
   - parameter engine: The `LayoutEngine` to associate with this layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this field.
   */
  public init(field: Field, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.field = field
    self.measurer = measurer
    super.init(engine: engine)

    field.listeners.add(self)
  }

  deinit {
    field.listeners.remove(self)
  }

  // MARK: - Super

  open override func performLayout(includeChildren: Bool) {
    // Measure the layout in the UIView coordinate system
    let layoutSize: CGSize = measurer.measureLayout(self, scale: self.engine.scale)

    // Convert the layout size back into the Workspace coordinate system
    self.contentSize = self.engine.workspaceSizeFromViewSize(layoutSize)

    // Force this field to be redisplayed
    sendChangeEvent(withFlags: Layout.Flag_NeedsDisplay)
  }

  // MARK: - Update

  /**
   Sets the native value of this field from a serialized text value.

   - parameter text: The serialized text value
   - throws:
   `BlocklyError`: Thrown if the serialized text value could not be converted into the field's
   native value.
   */
  public func setValue(fromSerializedText text: String) throws {
    try captureChangeEvent {
      try field.setValueFromSerializedText(text)
    }

    // Perform layout update since the field may need to be resized to reflect its new value.
    updateLayoutUpTree()
  }

  // MARK: - Change Events

  /**
   Automatically captures a `BlocklyEvent.Change` for `self.field`, based on its state before
   and after running a given closure block. This event is then added to the pending events queue
   on `EventManager.shared`.

   - parameter closure: A closure to execute, that will change the state of `self.field`.
   */
  open func captureChangeEvent(_ closure: () throws -> Void) rethrows {
    if let workspace = firstAncestor(ofType: WorkspaceLayout.self)?.workspace,
      let block = field.sourceInput?.sourceBlock
    {
      // Capture values before and after running update
      let oldValue = try? field.serializedText()
      try closure()
      let newValue = try? field.serializedText()

      if case let anOldValue?? = oldValue,
        case let aNewValue?? = newValue,
        anOldValue != aNewValue
      {
        let event = BlocklyEvent.Change.fieldValueEvent(
          workspace: workspace, block: block, field: field,
          oldValue: anOldValue, newValue: aNewValue)
        EventManager.shared.addPendingEvent(event)
      }
    } else {
      // Just run update
      try closure()
    }
  }
}

// MARK: - FieldListener implementation

extension FieldLayout: FieldListener {
  public func didUpdateField(_ field: Field) {
    // Refresh the field since it's been updated
    sendChangeEvent(withFlags: Layout.Flag_NeedsDisplay)
  }
}
