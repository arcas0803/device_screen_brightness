#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint device_screen_brightness.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'device_screen_brightness'
  s.version          = '0.0.1'
  s.summary          = 'Control screen brightness from Flutter via FFI.'
  s.description      = <<-DESC
Flutter FFI plugin for reading and writing the screen brightness on iOS
using UIScreen.mainScreen.brightness.
                       DESC
  s.homepage         = 'https://github.com/arcas0803/device_screen_brightness'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ArcasHH' => 'alvaroarcasgarcia@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'UIKit'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
