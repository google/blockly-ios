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

/*
Stores information on how to render and position a `FieldLabel` on-screen.
*/
@objc(BKYFieldLabelLayout)
public class FieldLabelLayout: FieldLayout {
  // MARK: - Static Properties

  /// The default Layout measurer to use for new instances of FieldLabelLayout.
  public static var defaultMeasurer: FieldLayoutMeasurer.Type = FieldLabelView.self

  // MARK: - Properties

  /// The `FieldLabel` to layout.
  public let fieldLabel: FieldLabel

  // MARK: - Initializers

  public required init(fieldLabel: FieldLabel, workspaceLayout: WorkspaceLayout) {
    self.fieldLabel = fieldLabel
    super.init(field: fieldLabel, workspaceLayout: workspaceLayout,
      measurer: FieldLabelLayout.defaultMeasurer)
  }
}
