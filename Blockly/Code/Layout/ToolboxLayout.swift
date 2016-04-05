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
  /// The associated list of `WorkspaceFlowLayout` instances for `toolbox.categories`
  public var categoryLayouts = [WorkspaceFlowLayout]()

  // MARK: - Initializers

  /**
   Creates a new `ToolboxLayout`.
  
   - Parameter toolbox: The `Toolbox` to associate with this object.
   - Parameter layoutDirection: The layout direction to use when creating new
   `WorkspaceFlowLayout` instances for each category in `toolbox`
   - Parameter engine: The layout engine to use when creating new `WorkspaceFlowLayout` instances
   for each category in `toolbox`
   - Parameter layoutBuilder: The layout builder to use when creating new `WorkspaceFlowLayout`
   instances for each category in `toolbox`
   */
  public init(toolbox: Toolbox, layoutDirection: WorkspaceFlowLayout.LayoutDirection,
    engine: LayoutEngine, layoutBuilder: LayoutBuilder)
  {
    self.toolbox = toolbox
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    self.layoutDirection = layoutDirection

    super.init()

    for category in self.toolbox.categories {
      addLayoutForToolboxCategory(category)
    }
  }

  // MARK: - Private

  private func addLayoutForToolboxCategory(category: Toolbox.Category) {
    do {
      let layout = try WorkspaceFlowLayout(workspace: category,
        layoutDirection: self.layoutDirection, engine: self.engine, layoutBuilder: layoutBuilder)
      categoryLayouts.append(layout)
    } catch let error as NSError {
      bky_assertionFailure("Could not create WorkspaceListLayout: \(error)")
    }
  }
}
