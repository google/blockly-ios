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
Contains methods to help measure how Strings will render in the UI.
*/
extension String {
  /**
   Computes the size of the bounding box that would be needed to render the current string,
   constrained to a maximum width.

   - Parameter attributes: A dictionary of text attributes to be applied to the string. These are the
   same attributes that can be applied to an NSAttributedString object, but in the case of NSString
   objects, the attributes apply to the entire string, rather than ranges within the string.
   - Parameter width: The maximum width the string can occupy when rendered.
   - Returns: The size required to render the string.
   */
  public func bky_multiLineSizeWithAttributes(
    attributes: [String : AnyObject]?, constrainedToWidth width: CGFloat) -> CGSize {
      let boundingBox = self.boundingRectWithSize(CGSizeMake(width, CGFloat(MAXFLOAT)),
        options: NSStringDrawingOptions.UsesLineFragmentOrigin,
        attributes: attributes,
        context: nil)

      // Use ceiling since you can't split a pixel
      return CGSizeMake(ceil(boundingBox.size.width), ceil(boundingBox.size.height))
  }

  /**
   Computes the size of the bounding box that would be needed to render the current string using a
   given font, constrained to a maximum width.

   - Parameter font: The font used to render the string.
   - Parameter width: The maximum width the string can occupy when rendered.
   - Returns: The size required to render the string.
  */
  public func bky_multiLineSizeForFont(font: UIFont, constrainedToWidth width: CGFloat) -> CGSize {
    let attributes = [NSFontAttributeName: font]
    return self.bky_multiLineSizeWithAttributes(attributes, constrainedToWidth: width)
  }

  /**
   Computes the size of the bounding box that would be needed to render the current string using a
   given font, on a single-line.

   - Parameter font: The font used to render the string.
   - Returns: The size required to render the string.
   */
  public func bky_singleLineSizeForFont(font: UIFont) -> CGSize {
    let attributes = [NSFontAttributeName: font]
    let boundingBox = self.boundingRectWithSize(CGSizeMake(CGFloat(MAXFLOAT), CGFloat(MAXFLOAT)),
      options: NSStringDrawingOptions.UsesLineFragmentOrigin,
      attributes: attributes,
      context: nil)

    // Return ceiling since you can't split a pixel
    return CGSizeMake(ceil(boundingBox.size.width), ceil(boundingBox.size.height))
  }
}
