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

typedef NS_ENUM(NSInteger, BKYWorkbenchViewControllerUIStateValue) {
  BKYWorkbenchViewControllerUIStateValueDefaultState = 1,
  BKYWorkbenchViewControllerUIStateValueTrashCanOpen,
  BKYWorkbenchViewControllerUIStateValueTrashCanHighlighted,
  BKYWorkbenchViewControllerUIStateValueCategoryOpen,
  BKYWorkbenchViewControllerUIStateValueEditingTextField,
  BKYWorkbenchViewControllerUIStateValueDraggingBlock,
  BKYWorkbenchViewControllerUIStateValuePresentingPopover,
  BKYWorkbenchViewControllerUIStateValueDidPanWorkspace,
  BKYWorkbenchViewControllerUIStateValueDidTapWorkspace,
};

typedef NS_OPTIONS(NSUInteger, BKYWorkbenchViewControllerUIState) {
  BKYWorkbenchViewControllerUIStateDefaultState CF_SWIFT_NAME(defaultState) =
    1 << BKYWorkbenchViewControllerUIStateValueDefaultState,
  BKYWorkbenchViewControllerUIStateTrashCanOpen CF_SWIFT_NAME(trashCanOpen) =
    1 << BKYWorkbenchViewControllerUIStateValueTrashCanOpen,
  BKYWorkbenchViewControllerUIStateTrashCanHighlighted CF_SWIFT_NAME(trashCanHighlighted) =
    1 << BKYWorkbenchViewControllerUIStateValueTrashCanHighlighted,
  BKYWorkbenchViewControllerUIStateCategoryOpen CF_SWIFT_NAME(categoryOpen) =
    1 << BKYWorkbenchViewControllerUIStateValueCategoryOpen,
  BKYWorkbenchViewControllerUIStateEditingTextField CF_SWIFT_NAME(editingTextField) =
    1 << BKYWorkbenchViewControllerUIStateValueEditingTextField,
  BKYWorkbenchViewControllerUIStateDraggingBlock CF_SWIFT_NAME(draggingBlock) =
    1 << BKYWorkbenchViewControllerUIStateValueDraggingBlock,
  BKYWorkbenchViewControllerUIStatePresentingPopover CF_SWIFT_NAME(presentingPopover) =
    1 << BKYWorkbenchViewControllerUIStateValuePresentingPopover,
  BKYWorkbenchViewControllerUIStateDidPanWorkspace CF_SWIFT_NAME(didPanWorkspace) =
    1 << BKYWorkbenchViewControllerUIStateValueDidPanWorkspace,
  BKYWorkbenchViewControllerUIStateDidTapWorkspace CF_SWIFT_NAME(didTapWorkspace) =
    1 << BKYWorkbenchViewControllerUIStateValueDidTapWorkspace,
};
