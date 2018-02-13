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
  s.version          = '1.2.2'
  s.summary          = 'A library from Google for building visual programming editors.'
  s.description      = <<-DESC
  Blockly is a visual editor that allows users to write programs by plugging blocks together.
  Developers can integrate the Blockly editor into their own applications to create a great
  UI for novice users.
                       DESC

  s.homepage         = 'https://developers.google.com/blockly/'
  s.license          = 'Apache License, Version 2.0'
  s.author           = 'Google Inc.'
  s.source           = {
                         :git => 'https://github.com/google/blockly-ios.git',
                         :tag => s.version.to_s
                       }
  s.screenshots      = ['https://google.github.io/blockly-ios/demo.gif']

  s.platform         = :ios, '10.0'
  s.ios.deployment_target = '8.0'
  s.requires_arc     = true

  s.source_files     = 'Sources/**/*'

  # It appears resources inside xcassets can't be loaded from packaged resource bundles, so that
  # is why we use '.resources', instead of '.resource_bundles' (or else Blockly.xcassets wouldn't
  # be included properly).
  s.resources = [
    # Import non-localized files so that their folder structure is maintained in Xcode.
    'Resources/Non-Localized/**',

    # This will import localized files so that .lproj folders properly group localized files
    # in Xcode. If it is done as simply a wildcard ("**"), they will be imported as folders
    # not groups, and localization will not work.
    # NOTE: A file without an extension, specifically located in the "Localized" directory will
    # not get picked up. This shouldn't happen in practice though.
    'Resources/Localized/*.*',
    'Resources/Localized/**/*[^.][^l][^p][^r][^o][^j]/*',
    'Resources/Localized/**/*.lproj/*']

  s.frameworks        = 'WebKit'
  s.ios.dependency 'AEXML', '~> 4.1.0'

  s.pod_target_xcconfig = {
      # Enable whole-module-optimization for all builds except for Debug builds
      'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule',
      'SWIFT_OPTIMIZATION_LEVEL[config=Debug]' => '-Onone',

      # Let Xcode know Blockly uses Swift 4.0 syntax
      'SWIFT_VERSION' => '4.0',

      # Add DEBUG compiler flag for debug builds
      'OTHER_SWIFT_FLAGS[config=Debug]' => '-D DEBUG',
  }

  s.user_target_xcconfig = {
    # Swift standard libraries need to be included for Blockly to work!
    # NOTE: This needs to be done at the app level, not at the framework level, or
    # else an error could occur when uploading to the App Store.
    'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES' => 'YES'
  }

end
