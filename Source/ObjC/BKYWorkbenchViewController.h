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

/// Specifies the bitflags for `BKYWorkbenchViewControllerUIState`.
typedef NS_ENUM(NSUInteger, BKYWorkbenchViewControllerUIStateValue) {
  /// The default (zero) state for the workbench.
  BKYWorkbenchViewControllerUIStateValueDefaultState = 1,
  /// Specifies the trash can is open.
  BKYWorkbenchViewControllerUIStateValueTrashCanOpen,
  /// Specifies the trash can is highlighted.
  BKYWorkbenchViewControllerUIStateValueTrashCanHighlighted,
  /// Specifies a toolbox category is open.
  BKYWorkbenchViewControllerUIStateValueCategoryOpen,
  /// Specifies a text field is being edited.
  BKYWorkbenchViewControllerUIStateValueEditingTextField,
  /// Specifies a block is currently being dragged.
  BKYWorkbenchViewControllerUIStateValueDraggingBlock,
  /// Specifies a popover is being presented.
  BKYWorkbenchViewControllerUIStateValuePresentingPopover,
  /// Specifies the user panned the workspace.
  BKYWorkbenchViewControllerUIStateValueDidPanWorkspace,
  /// Specifies the user tapped the workspace.
  BKYWorkbenchViewControllerUIStateValueDidTapWorkspace,
} CF_SWIFT_NAME(WorkbenchViewControllerUIStateValue);

/// Details the bitflags for `WorkbenchViewController`'s state.
typedef NS_OPTIONS(NSUInteger, BKYWorkbenchViewControllerUIState) {
  /// The default (zero) state for the workbench.
  BKYWorkbenchViewControllerUIStateDefaultState CF_SWIFT_NAME(defaultState) =
    1 << BKYWorkbenchViewControllerUIStateValueDefaultState,
  /// Specifies the trash can is open.
  BKYWorkbenchViewControllerUIStateTrashCanOpen CF_SWIFT_NAME(trashCanOpen) =
    1 << BKYWorkbenchViewControllerUIStateValueTrashCanOpen,
  /// Specifies the trash can is highlighted.
  BKYWorkbenchViewControllerUIStateTrashCanHighlighted CF_SWIFT_NAME(trashCanHighlighted) =
    1 << BKYWorkbenchViewControllerUIStateValueTrashCanHighlighted,
  /// Specifies a toolbox category is open.
  BKYWorkbenchViewControllerUIStateCategoryOpen CF_SWIFT_NAME(categoryOpen) =
    1 << BKYWorkbenchViewControllerUIStateValueCategoryOpen,
  /// Specifies a text field is being edited.
  BKYWorkbenchViewControllerUIStateEditingTextField CF_SWIFT_NAME(editingTextField) =
    1 << BKYWorkbenchViewControllerUIStateValueEditingTextField,
  /// Specifies a block is currently being dragged.
  BKYWorkbenchViewControllerUIStateDraggingBlock CF_SWIFT_NAME(draggingBlock) =
    1 << BKYWorkbenchViewControllerUIStateValueDraggingBlock,
  /// Specifies a popover is being presented.
  BKYWorkbenchViewControllerUIStatePresentingPopover CF_SWIFT_NAME(presentingPopover) =
    1 << BKYWorkbenchViewControllerUIStateValuePresentingPopover,
  /// Specifies the user panned the workspace.
  BKYWorkbenchViewControllerUIStateDidPanWorkspace CF_SWIFT_NAME(didPanWorkspace) =
    1 << BKYWorkbenchViewControllerUIStateValueDidPanWorkspace,
  /// Specifies the user tapped the workspace.
  BKYWorkbenchViewControllerUIStateDidTapWorkspace CF_SWIFT_NAME(didTapWorkspace) =
    1 << BKYWorkbenchViewControllerUIStateValueDidTapWorkspace,
} CF_SWIFT_NAME(WorkbenchViewControllerUIState);
