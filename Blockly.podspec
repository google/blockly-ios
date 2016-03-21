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
  s.version          = '0.1.0'
  s.summary          = 'A library for building visual programming editors.'
  s.description      = <<-DESC
  Blockly is a visual editor that allows users to write programs by plugging blocks together. Developers can integrate the Blockly editor into their own applications to create a great UI for novice users.
                       DESC

  s.homepage         = 'https://developers.google.com/blockly/'
  s.license          = 'Apache License, Version 2.0'
  s.author           = 'Google Inc.'
  s.source           = {
                         :git => 'https://github.com/RoboErikG/blocklypp.git',
                         #:tag => s.version.to_s
                       }

  s.platform         = :ios, '9.0'
  s.ios.deployment_target = '8.0'
  s.requires_arc     = true

  s.source_files     = 'Blockly/Code/**/*'

  # It appears resources inside xcassets can't be loaded from packaged resource bundles, so that
  # is why we include Blockly.xcassets through '.resources', instead of '.resource_bundles'.
  s.resources = ['Blockly/Resources/Blockly.xcassets', 'Blockly/Resources/code_generator']

  s.frameworks        = 'WebKit'
  s.ios.dependency 'AEXML', '~> 2.1'

  # Enable whole-module-optimization for all builds except for Debug builds
  s.pod_target_xcconfig = {
      'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule',
      'SWIFT_OPTIMIZATION_LEVEL[config=Debug]' => '-Onone',
  }
end
