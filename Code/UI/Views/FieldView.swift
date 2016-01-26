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
 Abstract view for rendering a `FieldLayout`.
 */
@objc(BKYFieldView)
public class FieldView: LayoutView {
  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    // Use this opportunity to enable/disable user interaction based on the field's editable
    // property
    guard let layout = self.layout as? FieldLayout else {
      return
    }

    self.userInteractionEnabled = layout.field.editable
  }
}
