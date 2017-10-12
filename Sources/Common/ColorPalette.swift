/*
 * Copyright 2017 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License"");
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
 Simplistic representation of the [Material Design color
 palette](https://material.io/guidelines/style/color.html#color-color-tool).
 */
@objc(BKYColorPalette)
@objcMembers public final class ColorPalette: NSObject {
  // MARK: - Properties

  /// The 50 tint color, the lightest tint of the palette.
  public let tint50: UIColor
  /// The 100 tint color.
  public let tint100: UIColor
  /// The 200 tint color.
  public let tint200: UIColor
  /// The 300 tint color.
  public let tint300: UIColor
  /// The 400 tint color.
  public let tint400: UIColor
  /// The 500 tint color.
  public let tint500: UIColor
  /// The 600 tint color.
  public let tint600: UIColor
  /// The 700 tint color.
  public let tint700: UIColor
  /// The 800 tint color.
  public let tint800: UIColor
  /// The 900 tint color, the darkest tint of the palette.
  public let tint900: UIColor
  /// The A100 accent color, the lightest accent color.
  public let accent100: UIColor?
  /// The A200 accent color.
  public let accent200: UIColor?
  /// The A400 accent color, the darkest accent color.
  public let accent400: UIColor?
  /// The A700 accent color, the darkest accent color.
  public let accent700: UIColor?

  // MARK: - Initializers

  /**
   Creates a palette from a given set of tints and accents.
   */
  public init(
    tint50: UIColor,
    tint100: UIColor,
    tint200: UIColor,
    tint300: UIColor,
    tint400: UIColor,
    tint500: UIColor,
    tint600: UIColor,
    tint700: UIColor,
    tint800: UIColor,
    tint900: UIColor,
    accent100: UIColor? = nil,
    accent200: UIColor? = nil,
    accent400: UIColor? = nil,
    accent700: UIColor? = nil) {
    self.tint50 = tint50
    self.tint100 = tint100
    self.tint200 = tint200
    self.tint300 = tint300
    self.tint400 = tint400
    self.tint500 = tint500
    self.tint600 = tint600
    self.tint700 = tint700
    self.tint800 = tint800
    self.tint900 = tint900
    self.accent100 = accent100
    self.accent200 = accent200
    self.accent400 = accent400
    self.accent700 = accent700
  }

  // MARK: - Material Design Palettes

  /// The red palette.
  public static let red = ColorPalette(
    tint50: makeColor(rgb: "FFEBEE"),
    tint100: makeColor(rgb: "FFCDD2"),
    tint200: makeColor(rgb: "EF9A9A"),
    tint300: makeColor(rgb: "E57373"),
    tint400: makeColor(rgb: "EF5350"),
    tint500: makeColor(rgb: "F44336"),
    tint600: makeColor(rgb: "E53935"),
    tint700: makeColor(rgb: "D32F2F"),
    tint800: makeColor(rgb: "C62828"),
    tint900: makeColor(rgb: "B71C1C"),
    accent100: makeColor(rgb: "FF8A80"),
    accent200: makeColor(rgb: "FF5252"),
    accent400: makeColor(rgb: "FF1744"),
    accent700: makeColor(rgb: "D50000"))

  /// The pink palette.
  public static let pink = ColorPalette(
    tint50: makeColor(rgb: "FCE4EC"),
    tint100: makeColor(rgb: "F8BBD0"),
    tint200: makeColor(rgb: "F48FB1"),
    tint300: makeColor(rgb: "F06292"),
    tint400: makeColor(rgb: "EC407A"),
    tint500: makeColor(rgb: "E91E63"),
    tint600: makeColor(rgb: "D81B60"),
    tint700: makeColor(rgb: "C2185B"),
    tint800: makeColor(rgb: "AD1457"),
    tint900: makeColor(rgb: "880E4F"),
    accent100: makeColor(rgb: "FF80AB"),
    accent200: makeColor(rgb: "FF4081"),
    accent400: makeColor(rgb: "F50057"),
    accent700: makeColor(rgb: "C51162"))

  /// The purple palette.
  public static let purple = ColorPalette(
    tint50: makeColor(rgb: "F3E5F5"),
    tint100: makeColor(rgb: "E1BEE7"),
    tint200: makeColor(rgb: "CE93D8"),
    tint300: makeColor(rgb: "BA68C8"),
    tint400: makeColor(rgb: "AB47BC"),
    tint500: makeColor(rgb: "9C27B0"),
    tint600: makeColor(rgb: "8E24AA"),
    tint700: makeColor(rgb: "7B1FA2"),
    tint800: makeColor(rgb: "6A1B9A"),
    tint900: makeColor(rgb: "4A148C"),
    accent100: makeColor(rgb: "EA80FC"),
    accent200: makeColor(rgb: "E040FB"),
    accent400: makeColor(rgb: "D500F9"),
    accent700: makeColor(rgb: "AA00FF"))

  /// The deep purple palette.
  public static let deepPurple = ColorPalette(
    tint50: makeColor(rgb: "EDE7F6"),
    tint100: makeColor(rgb: "D1C4E9"),
    tint200: makeColor(rgb: "B39DDB"),
    tint300: makeColor(rgb: "9575CD"),
    tint400: makeColor(rgb: "7E57C2"),
    tint500: makeColor(rgb: "673AB7"),
    tint600: makeColor(rgb: "5E35B1"),
    tint700: makeColor(rgb: "512DA8"),
    tint800: makeColor(rgb: "4527A0"),
    tint900: makeColor(rgb: "311B92"),
    accent100: makeColor(rgb: "B388FF"),
    accent200: makeColor(rgb: "7C4DFF"),
    accent400: makeColor(rgb: "651FFF"),
    accent700: makeColor(rgb: "6200EA"))

  /// The indigo palette.
  public static let indigo = ColorPalette(
    tint50: makeColor(rgb: "E8EAF6"),
    tint100: makeColor(rgb: "C5CAE9"),
    tint200: makeColor(rgb: "9FA8DA"),
    tint300: makeColor(rgb: "7986CB"),
    tint400: makeColor(rgb: "5C6BC0"),
    tint500: makeColor(rgb: "3F51B5"),
    tint600: makeColor(rgb: "3949AB"),
    tint700: makeColor(rgb: "303F9F"),
    tint800: makeColor(rgb: "283593"),
    tint900: makeColor(rgb: "1A237E"),
    accent100: makeColor(rgb: "8C9EFF"),
    accent200: makeColor(rgb: "536DFE"),
    accent400: makeColor(rgb: "3D5AFE"),
    accent700: makeColor(rgb: "304FFE"))

  /// The blue palette.
  public static let blue = ColorPalette(
    tint50: makeColor(rgb: "E3F2FD"),
    tint100: makeColor(rgb: "BBDEFB"),
    tint200: makeColor(rgb: "90CAF9"),
    tint300: makeColor(rgb: "64B5F6"),
    tint400: makeColor(rgb: "42A5F5"),
    tint500: makeColor(rgb: "2196F3"),
    tint600: makeColor(rgb: "1E88E5"),
    tint700: makeColor(rgb: "1976D2"),
    tint800: makeColor(rgb: "1565C0"),
    tint900: makeColor(rgb: "0D47A1"),
    accent100: makeColor(rgb: "82B1FF"),
    accent200: makeColor(rgb: "448AFF"),
    accent400: makeColor(rgb: "2979FF"),
    accent700: makeColor(rgb: "2962FF"))

  /// The light blue palette.
  public static let lightBlue = ColorPalette(
    tint50: makeColor(rgb: "E1F5FE"),
    tint100: makeColor(rgb: "B3E5FC"),
    tint200: makeColor(rgb: "81D4FA"),
    tint300: makeColor(rgb: "4FC3F7"),
    tint400: makeColor(rgb: "29B6F6"),
    tint500: makeColor(rgb: "03A9F4"),
    tint600: makeColor(rgb: "039BE5"),
    tint700: makeColor(rgb: "0288D1"),
    tint800: makeColor(rgb: "0277BD"),
    tint900: makeColor(rgb: "01579B"),
    accent100: makeColor(rgb: "80D8FF"),
    accent200: makeColor(rgb: "40C4FF"),
    accent400: makeColor(rgb: "00B0FF"),
    accent700: makeColor(rgb: "0091EA"))

  /// The cyan palette.
  public static let cyan = ColorPalette(
    tint50: makeColor(rgb: "E0F7FA"),
    tint100: makeColor(rgb: "B2EBF2"),
    tint200: makeColor(rgb: "80DEEA"),
    tint300: makeColor(rgb: "4DD0E1"),
    tint400: makeColor(rgb: "26C6DA"),
    tint500: makeColor(rgb: "00BCD4"),
    tint600: makeColor(rgb: "00ACC1"),
    tint700: makeColor(rgb: "0097A7"),
    tint800: makeColor(rgb: "00838F"),
    tint900: makeColor(rgb: "006064"),
    accent100: makeColor(rgb: "84FFFF"),
    accent200: makeColor(rgb: "18FFFF"),
    accent400: makeColor(rgb: "00E5FF"),
    accent700: makeColor(rgb: "00B8D4"))

  /// The teal palette.
  public static let teal = ColorPalette(
    tint50: makeColor(rgb: "E0F2F1"),
    tint100: makeColor(rgb: "B2DFDB"),
    tint200: makeColor(rgb: "80CBC4"),
    tint300: makeColor(rgb: "4DB6AC"),
    tint400: makeColor(rgb: "26A69A"),
    tint500: makeColor(rgb: "009688"),
    tint600: makeColor(rgb: "00897B"),
    tint700: makeColor(rgb: "00796B"),
    tint800: makeColor(rgb: "00695C"),
    tint900: makeColor(rgb: "004D40"),
    accent100: makeColor(rgb: "A7FFEB"),
    accent200: makeColor(rgb: "64FFDA"),
    accent400: makeColor(rgb: "1DE9B6"),
    accent700: makeColor(rgb: "00BFA5"))

  /// The green palette.
  public static let green = ColorPalette(
    tint50: makeColor(rgb: "E8F5E9"),
    tint100: makeColor(rgb: "C8E6C9"),
    tint200: makeColor(rgb: "A5D6A7"),
    tint300: makeColor(rgb: "81C784"),
    tint400: makeColor(rgb: "66BB6A"),
    tint500: makeColor(rgb: "4CAF50"),
    tint600: makeColor(rgb: "43A047"),
    tint700: makeColor(rgb: "388E3C"),
    tint800: makeColor(rgb: "2E7D32"),
    tint900: makeColor(rgb: "1B5E20"),
    accent100: makeColor(rgb: "B9F6CA"),
    accent200: makeColor(rgb: "69F0AE"),
    accent400: makeColor(rgb: "00E676"),
    accent700: makeColor(rgb: "00C853"))

  /// The light green palette.
  public static let lightGreen = ColorPalette(
    tint50: makeColor(rgb: "F1F8E9"),
    tint100: makeColor(rgb: "DCEDC8"),
    tint200: makeColor(rgb: "C5E1A5"),
    tint300: makeColor(rgb: "AED581"),
    tint400: makeColor(rgb: "9CCC65"),
    tint500: makeColor(rgb: "8BC34A"),
    tint600: makeColor(rgb: "7CB342"),
    tint700: makeColor(rgb: "689F38"),
    tint800: makeColor(rgb: "558B2F"),
    tint900: makeColor(rgb: "33691E"),
    accent100: makeColor(rgb: "CCFF90"),
    accent200: makeColor(rgb: "B2FF59"),
    accent400: makeColor(rgb: "76FF03"),
    accent700: makeColor(rgb: "64DD17"))

  /// The lime palette.
  public static let lime = ColorPalette(
    tint50: makeColor(rgb: "F9FBE7"),
    tint100: makeColor(rgb: "F0F4C3"),
    tint200: makeColor(rgb: "E6EE9C"),
    tint300: makeColor(rgb: "DCE775"),
    tint400: makeColor(rgb: "D4E157"),
    tint500: makeColor(rgb: "CDDC39"),
    tint600: makeColor(rgb: "C0CA33"),
    tint700: makeColor(rgb: "AFB42B"),
    tint800: makeColor(rgb: "9E9D24"),
    tint900: makeColor(rgb: "827717"),
    accent100: makeColor(rgb: "F4FF81"),
    accent200: makeColor(rgb: "EEFF41"),
    accent400: makeColor(rgb: "C6FF00"),
    accent700: makeColor(rgb: "AEEA00"))

  /// The yellow palette.
  public static let yellow = ColorPalette(
    tint50: makeColor(rgb: "FFFDE7"),
    tint100: makeColor(rgb: "FFF9C4"),
    tint200: makeColor(rgb: "FFF59D"),
    tint300: makeColor(rgb: "FFF176"),
    tint400: makeColor(rgb: "FFEE58"),
    tint500: makeColor(rgb: "FFEB3B"),
    tint600: makeColor(rgb: "FDD835"),
    tint700: makeColor(rgb: "FBC02D"),
    tint800: makeColor(rgb: "F9A825"),
    tint900: makeColor(rgb: "F57F17"),
    accent100: makeColor(rgb: "FFFF8D"),
    accent200: makeColor(rgb: "FFFF00"),
    accent400: makeColor(rgb: "FFEA00"),
    accent700: makeColor(rgb: "FFD600"))

  /// The amber palette.
  public static let amber = ColorPalette(
    tint50: makeColor(rgb: "FFF8E1"),
    tint100: makeColor(rgb: "FFECB3"),
    tint200: makeColor(rgb: "FFE082"),
    tint300: makeColor(rgb: "FFD54F"),
    tint400: makeColor(rgb: "FFCA28"),
    tint500: makeColor(rgb: "FFC107"),
    tint600: makeColor(rgb: "FFB300"),
    tint700: makeColor(rgb: "FFA000"),
    tint800: makeColor(rgb: "FF8F00"),
    tint900: makeColor(rgb: "FF6F00"),
    accent100: makeColor(rgb: "FFE57F"),
    accent200: makeColor(rgb: "FFD740"),
    accent400: makeColor(rgb: "FFC400"),
    accent700: makeColor(rgb: "FFAB00"))

  /// The orange palette.
  public static let orange = ColorPalette(
    tint50: makeColor(rgb: "FFF3E0"),
    tint100: makeColor(rgb: "FFE0B2"),
    tint200: makeColor(rgb: "FFCC80"),
    tint300: makeColor(rgb: "FFB74D"),
    tint400: makeColor(rgb: "FFA726"),
    tint500: makeColor(rgb: "FF9800"),
    tint600: makeColor(rgb: "FB8C00"),
    tint700: makeColor(rgb: "F57C00"),
    tint800: makeColor(rgb: "EF6C00"),
    tint900: makeColor(rgb: "E65100"),
    accent100: makeColor(rgb: "FFD180"),
    accent200: makeColor(rgb: "FFAB40"),
    accent400: makeColor(rgb: "FF9100"),
    accent700: makeColor(rgb: "FF6D00"))

  /// The deep orange palette.
  public static let deepOrange = ColorPalette(
    tint50: makeColor(rgb: "FBE9E7"),
    tint100: makeColor(rgb: "FFCCBC"),
    tint200: makeColor(rgb: "FFAB91"),
    tint300: makeColor(rgb: "FF8A65"),
    tint400: makeColor(rgb: "FF7043"),
    tint500: makeColor(rgb: "FF5722"),
    tint600: makeColor(rgb: "F4511E"),
    tint700: makeColor(rgb: "E64A19"),
    tint800: makeColor(rgb: "D84315"),
    tint900: makeColor(rgb: "BF360C"),
    accent100: makeColor(rgb: "FF9E80"),
    accent200: makeColor(rgb: "FF6E40"),
    accent400: makeColor(rgb: "FF3D00"),
    accent700: makeColor(rgb: "DD2C00"))

  /// The brown palette.
  public static let brown = ColorPalette(
    tint50: makeColor(rgb: "EFEBE9"),
    tint100: makeColor(rgb: "D7CCC8"),
    tint200: makeColor(rgb: "BCAAA4"),
    tint300: makeColor(rgb: "A1887F"),
    tint400: makeColor(rgb: "8D6E63"),
    tint500: makeColor(rgb: "795548"),
    tint600: makeColor(rgb: "6D4C41"),
    tint700: makeColor(rgb: "5D4037"),
    tint800: makeColor(rgb: "4E342E"),
    tint900: makeColor(rgb: "3E2723"))

  /// The grey palette.
  public static let grey = ColorPalette(
    tint50: makeColor(rgb: "FAFAFA"),
    tint100: makeColor(rgb: "F5F5F5"),
    tint200: makeColor(rgb: "EEEEEE"),
    tint300: makeColor(rgb: "E0E0E0"),
    tint400: makeColor(rgb: "BDBDBD"),
    tint500: makeColor(rgb: "9E9E9E"),
    tint600: makeColor(rgb: "757575"),
    tint700: makeColor(rgb: "616161"),
    tint800: makeColor(rgb: "424242"),
    tint900: makeColor(rgb: "212121"))

  /// The blue grey palette.
  public static let blueGrey = ColorPalette(
    tint50: makeColor(rgb: "ECEFF1"),
    tint100: makeColor(rgb: "CFD8DC"),
    tint200: makeColor(rgb: "B0BEC5"),
    tint300: makeColor(rgb: "90A4AE"),
    tint400: makeColor(rgb: "78909C"),
    tint500: makeColor(rgb: "607D8B"),
    tint600: makeColor(rgb: "546E7A"),
    tint700: makeColor(rgb: "455A64"),
    tint800: makeColor(rgb: "37474F"),
    tint900: makeColor(rgb: "263238"))

  // MARK: - Helper

  private static func makeColor(rgb: String) -> UIColor {
    return ColorHelper.makeColor(rgb: rgb) ?? .clear
  }
}
