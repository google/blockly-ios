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

   - parameter attributes: A dictionary of text attributes to be applied to the string. These are
   the same attributes that can be applied to an NSAttributedString object, but in the case of NSString
   objects, the attributes apply to the entire string, rather than ranges within the string.
   - parameter width: The maximum width the string can occupy when rendered.
   - returns: The size required to render the string.
   */
  public func bky_multiLineSizeWithAttributes(
    _ attributes: [NSAttributedStringKey : Any]?, constrainedToWidth width: CGFloat) -> CGSize
  {
    let boundingBox = self.boundingRect(with: CGSize(width: width, height: CGFloat(MAXFLOAT)),
      options: NSStringDrawingOptions.usesLineFragmentOrigin,
      attributes: attributes,
      context: nil)

    // Use ceiling since you can't split a pixel
    return CGSize(width: ceil(boundingBox.size.width), height: ceil(boundingBox.size.height))
  }

  /**
   Computes the size of the bounding box that would be needed to render the current string using a
   given font, constrained to a maximum width.

   - parameter font: The font used to render the string.
   - parameter width: The maximum width the string can occupy when rendered.
   - returns: The size required to render the string.
  */
  public func bky_multiLineSize(forFont font: UIFont, constrainedToWidth width: CGFloat) -> CGSize
  {
    let attributes = [NSAttributedStringKey.font: font]
    return self.bky_multiLineSizeWithAttributes(attributes, constrainedToWidth: width)
  }

  /**
   Computes the size of the bounding box that would be needed to render the current string using a
   given font, on a single-line.

   - parameter font: The font used to render the string.
   - returns: The size required to render the string.
   */
  public func bky_singleLineSize(forFont font: UIFont) -> CGSize {
    let attributes = [NSAttributedStringKey.font: font]
    let boundingBox = self.boundingRect(
      with: CGSize(width: CGFloat(MAXFLOAT), height: CGFloat(MAXFLOAT)),
      options: NSStringDrawingOptions.usesLineFragmentOrigin,
      attributes: attributes,
      context: nil)

    // Return ceiling since you can't split a pixel
    return CGSize(width: ceil(boundingBox.size.width), height: ceil(boundingBox.size.height))
  }
}
