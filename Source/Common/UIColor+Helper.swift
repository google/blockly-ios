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
 Extends the `UIColor` class to support color formats needed by Blockly.
*/
extension UIColor {
  /**
   Returns a tuple representing the hue, saturation, brightness, and alpha values of this color.

   - returns: A tuple of the form `(hue: CGFloat, saturation: CGFloat, brightness: CGFloat,
   alpha: CGFloat)` where `hue`, `saturation`, `brightness`, and `alpha` are all values
   from [0.0, 1.0].
   */
  public func bky_hsba() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)
  {
    var value: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) = (0,0,0,0)
    getHue(&(value.hue),saturation: &(value.saturation), brightness: &(value.brightness),
      alpha: &(value.alpha))
    return value
  }

  /**
   Returns a tuple representing the red, green, blue, and alpha values of this color.

   - returns: A tuple of the form `(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)`
   where `red`, `green`, `blue`, and `alpha` are all values from [0.0, 1.0].
   */
  public func bky_rgba() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    var value: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) = (0,0,0,0)
    getRed(&(value.red), green: &(value.green), blue: &(value.blue), alpha: &(value.alpha))
    return value
  }
}
