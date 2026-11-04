Pod::Spec.new do |s|
  s.name             = 'PushPlatformSDK'
  s.version          = '1.2.9'
  s.summary          = 'PushPilot iOS SDK for APNs and VoIP notifications'
  s.description      = <<-DESC
Native iOS SDK for PushPilot push notifications.
Supports APNs, PushKit/VoIP, CallKit integration, and user management.
                       DESC
  s.homepage         = 'https://github.com/pushplatform/pushpilot-sdk-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'PushPilot contributors'
  s.source           = { :git => 'https://github.com/pushplatform/pushpilot-sdk-ios.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.5'
  s.default_subspec = 'App'

  s.subspec 'Extension' do |e|
    e.source_files = 'Sources/PushPlatformExtension/**/*.swift'
    e.frameworks = 'Foundation', 'UserNotifications'
    e.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'PRODUCT_MODULE_NAME' => 'PushPlatformExtension',
      'APPLICATION_EXTENSION_API_ONLY' => 'YES'
    }
  end

  s.subspec 'App' do |a|
    a.dependency 'PushPlatformSDK/Extension'
    a.source_files = 'Sources/PushPlatformSDK/**/*.swift'
    a.frameworks = 'Foundation', 'UIKit', 'UserNotifications', 'PushKit', 'CallKit', 'AVFoundation', 'Network', 'Security'
    a.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'PRODUCT_MODULE_NAME' => 'PushPlatformSDK',
      'APPLICATION_EXTENSION_API_ONLY' => 'NO'
    }
  end
end
