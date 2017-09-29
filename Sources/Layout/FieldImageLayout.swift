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
 Class for a `FieldImage`-based `Layout`.
 */
@objc(BKYFieldImageLayout)
@objcMembers open class FieldImageLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldImage` that backs this layout
  private let fieldImage: FieldImage

  /// The size of the image field, expressed as a Workspace coordinate system size
  open var size: WorkspaceSize {
    return fieldImage.size
  }

  /// Flag determining if this image should be flipped horizontally in RTL rendering.
  open var flipRtl: Bool {
    return fieldImage.flipRtl
  }

  // MARK: - Initializers

  /**
   Initializes the image field layout.

   - parameter fieldImage: The `FieldImage` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(fieldImage: FieldImage, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldImage = fieldImage
    super.init(field: fieldImage, engine: engine, measurer: measurer)
  }

  // MARK: - Public

  /**
   Asynchronously loads this layout's image in the background and executes a callback on the main
   thread with the loaded image.

   - parameter completion: The callback method that will be executed on completion of this method.
   The `image` parameter of the callback method contains the `UIImage` that was loaded. If it is
   `nil`, the image could not be loaded.
   */
  open func loadImage(completion: @escaping ((_ image: UIImage?) -> Void)) {
    // Load image in the background
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { () -> Void in
      // Try loading from a local file first
      let imageLocation = self.fieldImage.imageLocation
      var image = ImageLoader.loadImage(named: imageLocation, forClass: FieldImageLayout.self)

      // Try loading image from the web (if we couldn't load from local)
      if image == nil,
        let url = URL(string: imageLocation)
      {
        do {
          let data = try Data(contentsOf: url, options: .alwaysMapped)
          image = UIImage(data: data)
        } catch {
          // Do nothing
        }
      }

      // Execute the callback on the main thread
      DispatchQueue.main.async(execute: { () -> Void in
        completion(image)
      })
    }
  }
}
