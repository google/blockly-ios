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

extension UIColor {
  /**
  Parses a RGB string and returns its corresponding color.

  - Parameter rgb: Supported formats are: (RRGGBB, #RRGGBB).
  - Parameter alpha: The alpha to set on the color. Defaults to 1.0, if none specified.
  - Returns: A parsed RGB color, or nil if the string could not be parsed.
  */
  public static func bky_colorFromRGB(var rgb: String, alpha: Float = 1.0) -> UIColor? {
    rgb = rgb.uppercaseString

    // Strip "#" if it exists
    if rgb.hasPrefix("#") {
      rgb = rgb.substringFromIndex(rgb.startIndex.successor())
    }

    // Verify that the string contains 6 valid hexidecimal characters
    let invalidCharacters = NSCharacterSet(charactersInString: "0123456789ABCDEF").invertedSet
    if (rgb.characters.count != 6 || rgb.rangeOfCharacterFromSet(invalidCharacters) != nil) {
      return nil
    }

    // Parse rgb as a hex value and return the color
    let scanner = NSScanner(string: rgb)
    var rgbValue: UInt32 = 0
    scanner.scanHexInt(&rgbValue)

    return UIColor(
      red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
      green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
      blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
      alpha: CGFloat(alpha))
  }

  /**
   - Returns: A tuple representing the hue, saturation, brightness, and alpha values of this color.
   */
  public func bky_hsba() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)
  {
    var value: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) = (0,0,0,0)
    getHue(&(value.hue),saturation: &(value.saturation), brightness: &(value.brightness),
      alpha: &(value.alpha))
    return value
  }
}
