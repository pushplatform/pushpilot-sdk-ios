#!/usr/bin/env ruby
# Build only: never launches the app, requests signing, or sends a push.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'xcodeproj'

revision = ARGV.fetch(0) { abort 'Usage: ruby scripts/check-spm-installation.rb <published-40-character-commit>' }
abort 'Expected an exact Git commit SHA' unless revision.match?(/\A[0-9a-f]{40}\z/)
repository = 'https://github.com/pushplatform/pushpilot-sdk-ios.git'
readme = File.read(File.expand_path('../README.md', __dir__))
source = readme.scan(/```swift\n(.*?)```/m).flatten.find { |block| block.start_with?('import UIKit') }
abort 'README AppDelegate example not found' unless source
root = Dir.mktmpdir('pushpilot-ios-spm-')
puts "Clean consumer: #{root}"
File.write(File.join(root, 'AppDelegate.swift'), source)
project = Xcodeproj::Project.new(File.join(root, 'CleanConsumer.xcodeproj'))
target = project.new_target(:application, 'CleanConsumer', :ios, '13.0')
target.add_file_references([project.main_group.new_file('AppDelegate.swift')])
target.build_configurations.each do |configuration|
  configuration.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.pushpilot.installationcheck',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'CODE_SIGNING_ALLOWED' => 'NO',
    'TARGETED_DEVICE_FAMILY' => '1,2'
  })
end
package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package.repositoryURL = repository
package.requirement = { 'kind' => 'revision', 'revision' => revision }
project.root_object.package_references << package
product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'PushPlatformSDK'
target.package_product_dependencies << product
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product
target.frameworks_build_phase.files << build_file
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.save_as(project.path, 'CleanConsumer', true)
command = [
  'xcodebuild', '-project', project.path.to_s, '-scheme', 'CleanConsumer',
  '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator',
  '-derivedDataPath', File.join(root, 'DerivedData'),
  '-clonedSourcePackagesDirPath', File.join(root, 'SourcePackages'),
  '-packageCachePath', File.join(root, 'PackageCache'),
  '-disablePackageRepositoryCache', 'CODE_SIGNING_ALLOWED=NO', 'build'
]
environment = {
  'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_CONFIG_GLOBAL' => '/dev/null',
  'GIT_TERMINAL_PROMPT' => '0', 'GIT_CONFIG_COUNT' => '1',
  'GIT_CONFIG_KEY_0' => 'credential.helper', 'GIT_CONFIG_VALUE_0' => ''
}
log_path = File.join(root, 'build.log')
success = File.open(log_path, 'w') { |log| system(environment, *command, out: log, err: log) }
puts "Build log: #{log_path}"
unless success
  warn File.readlines(log_path).last(60).join
  abort 'Clean SPM consumer build failed'
end
resolved = File.join(project.path, 'project.xcworkspace', 'xcshareddata', 'swiftpm', 'Package.resolved')
pins = JSON.parse(File.read(resolved)).fetch('pins')
abort 'Unexpected dependency graph' unless pins.length == 1 && pins.first.fetch('identity') == 'pushpilot-sdk-ios'
abort 'Resolved revision differs from requested commit' unless pins.first.fetch('state').fetch('revision') == revision
abort 'Unexpected package origin' unless pins.first.fetch('location') == repository
puts "BUILD SUCCEEDED: public Git package at #{revision}; one dependency; no signing; no app launch."
puts "Package.resolved: #{resolved}"
