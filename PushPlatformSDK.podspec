Pod::Spec.new do |s|
  s.name             = 'PushPlatformSDK'
  s.version          = '1.0.0'
  s.summary          = 'Native iOS SDK for Push Platform'
  s.description      = <<-DESC
Native iOS SDK for Push Platform push notifications.
Supports APNs, PushKit/VoIP, CallKit integration, and user management.
                       DESC
  s.homepage         = 'https://pushplatform.example'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Push Platform' => 'dev@pushplatform.example' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.5'

  s.source_files = 'Sources/PushPlatformSDK/**/*.swift'

  s.frameworks = 'Foundation', 'UIKit', 'UserNotifications', 'PushKit', 'CallKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
