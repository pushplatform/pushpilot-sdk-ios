Pod::Spec.new do |s|
  s.name             = 'PushPlatformSDK'
  s.version          = '1.0.0'
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

  s.source_files = 'Sources/PushPlatformSDK/**/*.swift'

  s.frameworks = 'Foundation', 'UIKit', 'UserNotifications', 'PushKit', 'CallKit', 'AVFoundation', 'Network', 'Security'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
