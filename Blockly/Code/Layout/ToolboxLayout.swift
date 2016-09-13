/*
* Copyright 2016 Google Inc. All Rights Reserved.
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
 Class responsible for maintaining associated `WorkspaceFlowLayout` instances for each
 `Toolbox.Category` inside of a `Toolbox`.

 - Note: The `Toolbox` itself does not have an associated `Layout` instance.
 */
@objc(BKYToolboxLayout)
public class ToolboxLayout: NSObject {

  // MARK: - Properties

  /// The associated toolbox
  public let toolbox: Toolbox
  /// The layout direction to use when creating new `WorkspaceFlowLayout` instances for each
  /// category in `toolbox`
  public let layoutDirection: WorkspaceFlowLayout.LayoutDirection
  /// The layout engine to use when creating new `WorkspaceFlowLayout` instances for each
  /// category in `toolbox`
  public let engine: LayoutEngine
  /// The layout builder to use when creating new `WorkspaceFlowLayout` instances for each
  /// category in `toolbox`
  public let layoutBuilder: LayoutBuilder
  /// The associated list of `WorkspaceLayoutCoordinator` instances for `toolbox.categories`
  public var categoryLayoutCoordinators = [WorkspaceLayoutCoordinator]()

  // MARK: - Initializers

  /**
   Creates a new `ToolboxLayout`.
  
   - Parameter toolbox: The `Toolbox` to associate with this object.
   - Parameter engine: The layout engine to use when creating new `WorkspaceFlowLayout` instances
   for each category in `toolbox`
   - Parameter layoutDirection: The layout direction to use when creating new
   `WorkspaceFlowLayout` instances for each category in `toolbox`
   - Parameter layoutBuilder: The layout builder to use when creating new `WorkspaceFlowLayout`
   instances for each category in `toolbox`
   */
  public init(toolbox: Toolbox, engine: LayoutEngine,
              layoutDirection: WorkspaceFlowLayout.LayoutDirection, layoutBuilder: LayoutBuilder)
  {
    self.toolbox = toolbox
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    self.layoutDirection = layoutDirection

    super.init()

    for category in self.toolbox.categories {
      addLayoutCoordinatorForToolboxCategory(category)
    }
  }

  // MARK: - Private

  private func addLayoutCoordinatorForToolboxCategory(category: Toolbox.Category) {
    do {
      let layout =
        WorkspaceFlowLayout(workspace: category, engine: engine, layoutDirection: layoutDirection)
      let coordinator = try WorkspaceLayoutCoordinator(
        workspaceLayout: layout, layoutBuilder: layoutBuilder, connectionManager: nil)
      categoryLayoutCoordinators.append(coordinator)
    } catch let error as NSError {
      bky_assertionFailure("Could not create WorkspaceListLayout: \(error)")
    }
  }
}
