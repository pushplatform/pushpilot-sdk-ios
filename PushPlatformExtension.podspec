Pod::Spec.new do |s|
  s.name             = 'PushPlatformExtension'
  s.version          = '1.2.10'
  s.summary          = 'PushPilot Notification Service Extension helpers'
  s.description      = <<-DESC
Extension-safe PushPilot helpers for confirming notification delivery from a
Notification Service Extension. No UIKit, PushKit, or CallKit.
                       DESC
  s.homepage         = 'https://github.com/pushplatform/pushpilot-sdk-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'PushPilot contributors'
  s.source           = { :git => 'https://github.com/pushplatform/pushpilot-sdk-ios.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.5'

  s.source_files = 'Sources/PushPlatformExtension/**/*.swift'
  s.frameworks = 'Foundation', 'UserNotifications'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES'
  }
end
