/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

// TODO(#57): Once Jazzy supports the CF_SWIFT_NAME getter macro, add that in BKYEdgeInsets.h and
// delete this file.

/**
 Defines helper extension methods for `EdgeInsets`.
 */
extension EdgeInsets {
  /**
   The inset distance for the left edge.
   In LTR layouts, this value is equal to `self.leading`.
   In RTL layouts, this value is equal to `self.trailing`.
   */
  public var left: CGFloat {
    return BKYEdgeInsetsGetLeft(self)
  }

  /**
   The inset distance for the right edge.
   In LTR layouts, this value is equal to `self.trailing`.
   In RTL layouts, this value is equal to `self.leading`.
   */
  public var right: CGFloat {
    return BKYEdgeInsetsGetRight(self)
  }
}
