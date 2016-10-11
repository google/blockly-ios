#
# Be sure to run `pod lib lint Blockly.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Blockly'
  s.module_name      = 'Blockly'
  s.version          = '0.5'
  s.summary          = 'A library from Google for building visual programming editors.'
  s.description      = <<-DESC
  Blockly is a visual editor that allows users to write programs by plugging blocks together. Developers can integrate the Blockly editor into their own applications to create a great UI for novice users.
                       DESC

  s.homepage         = 'https://developers.google.com/blockly/'
  s.license          = 'Apache License, Version 2.0'
  s.author           = 'Google Inc.'
  s.source           = {
                         :git => 'https://github.com/google/blockly-ios.git',
                         :tag => s.version.to_s
                       }

  s.platform         = :ios, '10.0'
  s.ios.deployment_target = '8.0'
  s.requires_arc     = true

  s.source_files     = 'Source/**/*'

  # It appears resources inside xcassets can't be loaded from packaged resource bundles, so that
  # is why we use '.resources', instead of '.resource_bundles' (or else Blockly.xcassets wouldn't
  # be included properly).
  s.resources = 'Resources/**'

  s.frameworks        = 'WebKit'
  s.ios.dependency 'AEXML', '~> 4.0.1'

  s.pod_target_xcconfig = {
      # Enable whole-module-optimization for all builds except for Debug builds
      'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule',
      'SWIFT_OPTIMIZATION_LEVEL[config=Debug]' => '-Onone',

      # Let Xcode know Blockly uses Swift 3.0 syntax
      'SWIFT_VERSION' => '3.0',

      # Swift standard libraries need to be included for Blockly to work!
      'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES' => 'YES',
  }

end
