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

/*
Stores information on how to render and position a `FieldImage` on-screen.
*/
@objc(BKYFieldImageLayout)
public class FieldImageLayout: FieldLayout {
  // MARK: - Static Properties

  /// The default Layout measurer to use for new instances of FieldImageLayout.
  public static var defaultMeasurer: FieldLayoutMeasurer.Type = FieldImageView.self

  // MARK: - Properties

  /// The `FieldImage` to layout.
  public let fieldImage: FieldImage

  // MARK: - Initializers

  public required init(fieldImage: FieldImage, workspaceLayout: WorkspaceLayout) {
    self.fieldImage = fieldImage
    super.init(field: fieldImage, workspaceLayout: workspaceLayout,
      measurer: FieldImageLayout.defaultMeasurer)
  }
}
