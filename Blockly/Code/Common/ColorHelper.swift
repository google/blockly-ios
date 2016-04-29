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
 Utility class for creating `UIColor` instances.
 */
@objc(BKYColorHelper)
public class ColorHelper: NSObject {
  /**
   Parses a RGB string and returns its corresponding color.

   - Parameter rgb: Supported formats are: (RRGGBB, #RRGGBB).
   - Parameter alpha: The alpha to set on the color. Defaults to 1.0, if none specified.
   - Returns: A parsed RGB color, or nil if the string could not be parsed.
   */
  public static func colorFromRGB(rgb: String, alpha: Float = 1.0) -> UIColor? {
    var rgbUpper = rgb.uppercaseString

    // Strip "#" if it exists
    if rgbUpper.hasPrefix("#") {
      rgbUpper = rgbUpper.substringFromIndex(rgbUpper.startIndex.successor())
    }

    // Verify that the string contains 6 valid hexidecimal characters
    let invalidCharacters = NSCharacterSet(charactersInString: "0123456789ABCDEF").invertedSet
    if rgbUpper.characters.count != 6 ||
      rgbUpper.rangeOfCharacterFromSet(invalidCharacters) != nil {
      return nil
    }

    // Parse rgb as a hex value and return the color
    let scanner = NSScanner(string: rgbUpper)
    var rgbValue: UInt32 = 0
    scanner.scanHexInt(&rgbValue)

    return UIColor(
      red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
      green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
      blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
      alpha: CGFloat(alpha))
  }

  /**
   Returns a `UIColor` based on hue, saturation, brightness, and alpha values.

   - Parameter hue: The hue
   - Parameter saturation: (Optional) The saturation. Defaults to 0.45.
   - Parameter brightness: (Optional) The brightness. Defaults to 0.65.
   - Parameter alpha: (Optional) The alpha. Defaults to 1.0.
   - Returns: A `UIColor`
   */
  public static func colorFromHue(hue: CGFloat, saturation: CGFloat = 0.45,
    brightness: CGFloat = 0.65, alpha: CGFloat = 1.0) -> UIColor
  {
    return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
  }
}
