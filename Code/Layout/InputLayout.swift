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

import UIKit

/*
Stores information for positioning |Input| areas on-screen.
*/
@objc(BKYInputLayout)
public class InputLayout: Layout {
  // MARK: - Properties

  public let input: Input
  public var fieldLayouts = [FieldLayout]()

  // MARK: - Initializers

  public required init(input: Input, parentLayout: Layout?) {
    self.input = input
    super.init(parentLayout: parentLayout)
    self.input.delegate = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return fieldLayouts
  }

  public override func layoutChildren() {
    // Update relative position/size of fields
    for fieldLayout in fieldLayouts {
      fieldLayout.layoutChildren()

      // TODO:(vicng) Figure out new positions for each field
    }

    self.size = sizeThatFitsForChildLayouts()
  }

  // MARK: - Public
}

// MARK: - InputDelegate

extension InputLayout: InputDelegate {
  public func inputDidChange(input: Input) {
    // TODO:(vicng) Potentially generate an event to update the source block of this input
  }
}
