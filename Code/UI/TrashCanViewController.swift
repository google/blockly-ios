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
 A view controller for displaying blocks .
 */
public class TrashCanViewController: UIViewController {

  // MARK: - Properties

  private var kvoContextBounds = 0

  /// The trash can to display
  public private(set) var workspaceLayout: WorkspaceFlowLayout!

  public var workspace: Workspace? {
    return workspaceLayout?.workspace
  }

  /// The view for displaying each category's set of blocks
  public var workspaceView: WorkspaceView {
    return self.view as! WorkspaceView
  }

  /// The constraint for resizing the width of `self.blockListView`
  private var blockListViewWidthConstraint: NSLayoutConstraint!

  // MARK: - Super

  public override func loadView() {
    super.loadView()

    do {
      self.workspaceLayout = try WorkspaceFlowLayout(
        workspace: WorkspaceFlow(), layoutDirection: .Horizontal, layoutBuilder: LayoutBuilder())

      let workspaceView = WorkspaceView()
      workspaceView.layout = workspaceLayout
      workspaceView.backgroundColor = UIColor(white: 0.6, alpha: 0.65)
      workspaceView.allowCanvasPadding = false
      workspaceView.addObserver(self,
        forKeyPath: "bounds", options: NSKeyValueObservingOptions.New, context: &kvoContextBounds)

      self.view = workspaceView

      updateMaximumLineBlockSize()
    } catch let error as NSError {
      bky_assertionFailure("Could not create WorkspaceFlowLayout: \(error)")
    }
  }

  public override func observeValueForKeyPath(
    keyPath: String?,
    ofObject object: AnyObject?,
    change: [String : AnyObject]?,
    context: UnsafeMutablePointer<Void>)
  {
    if context == &kvoContextBounds {
      updateMaximumLineBlockSize()
    } else {
      super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
    }
  }

  // MARK: - Private

  private func updateMaximumLineBlockSize() {
    // Constrain the workspace layout width to the view's width
    workspaceLayout.maximumLineBlockSize =
      workspaceLayout.workspaceUnitFromViewUnit(workspaceView.bounds.size.width)
    workspaceLayout.updateLayoutDownTree()
    workspaceView.refreshView()
    workspaceView.invalidateIntrinsicContentSize()
  }
}
