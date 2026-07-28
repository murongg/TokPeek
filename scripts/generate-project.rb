#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "xcodeproj"

project_root = File.expand_path("..", __dir__)
project_path = File.join(project_root, "TokPeek.xcodeproj")

FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2620"
project.root_object.attributes["LastUpgradeCheck"] = "2620"
project.root_object.known_regions = %w[en Base zh-Hans]

project.build_configurations.each do |configuration|
  configuration.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
  configuration.build_settings["SWIFT_VERSION"] = "6.0"
end

sources_group = project.main_group.new_group("Sources", "Sources")
resources_group = project.main_group.new_group("Resources", "Resources")
tests_group = project.main_group.new_group("Tests", "Tests")
rust_group = project.main_group.new_group("Rust", "rust")

app = project.new_target(:application, "TokPeek", :osx, "14.0")
app.product_reference.name = "TokPeek.app"

sparkle_package = project.new(
  Xcodeproj::Project::Object::XCRemoteSwiftPackageReference
)
sparkle_package.repositoryURL =
  "https://github.com/sparkle-project/Sparkle"
sparkle_package.requirement = {
  "kind" => "exactVersion",
  "version" => "2.9.4"
}
project.root_object.package_references << sparkle_package

sparkle_product = project.new(
  Xcodeproj::Project::Object::XCSwiftPackageProductDependency
)
sparkle_product.package = sparkle_package
sparkle_product.product_name = "Sparkle"
app.package_product_dependencies << sparkle_product

sparkle_build_file = project.new(
  Xcodeproj::Project::Object::PBXBuildFile
)
sparkle_build_file.product_ref = sparkle_product
app.frameworks_build_phase.files << sparkle_build_file

swift_sources = Dir[
  File.join(project_root, "Sources/TokPeekKit/*.swift"),
  File.join(project_root, "Sources/TokPeekBridge/*.swift"),
  File.join(project_root, "Sources/TokPeek/*.swift")
].sort

swift_sources.each do |source_path|
  relative_path = source_path.delete_prefix("#{project_root}/Sources/")
  reference = sources_group.new_file(relative_path)
  app.source_build_phase.add_file_reference(reference)
end

header_reference = sources_group.new_file(
  "CTokPeekCore/include/tokpeek_core.h"
)
header_reference.include_in_index = "1"

asset_catalog = resources_group.new_file("Assets.xcassets")
app.resources_build_phase.add_file_reference(asset_catalog)
localized_strings = resources_group.new_variant_group("Localizable.strings")
%w[en zh-Hans].each do |language|
  reference = localized_strings.new_file(
    "#{language}.lproj/Localizable.strings"
  )
  reference.name = language
end
app.resources_build_phase.add_file_reference(localized_strings)
resources_group.new_file("Info.plist")

archive_reference = rust_group.new_file(
  "target/universal/release/libtokpeek_core_ffi.a"
)
app.frameworks_build_phase.add_file_reference(archive_reference)

%w[
  Security.framework
  SystemConfiguration.framework
  CoreFoundation.framework
].each do |framework_name|
  reference = project.frameworks_group.new_file(
    "System/Library/Frameworks/#{framework_name}"
  )
  reference.source_tree = "SDKROOT"
  app.frameworks_build_phase.add_file_reference(reference)
end

rust_build_phase = app.new_shell_script_build_phase("Build Tokscale Core")
rust_build_phase.shell_path = "/bin/zsh"
rust_build_phase.shell_script = <<~SHELL
  set -euo pipefail
  export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"
  "$PROJECT_DIR/scripts/build-rust-universal.sh"
SHELL
rust_build_phase.always_out_of_date = "1"
app.build_phases.delete(rust_build_phase)
app.build_phases.unshift(rust_build_phase)

app.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.tokpeek.app"
  settings["PRODUCT_NAME"] = "TokPeek"
  settings["INFOPLIST_FILE"] = "Resources/Info.plist"
  settings["GENERATE_INFOPLIST_FILE"] = "NO"
  settings["SWIFT_OBJC_BRIDGING_HEADER"] =
    "Sources/CTokPeekCore/include/tokpeek_core.h"
  settings["SWIFT_STRICT_CONCURRENCY"] = "complete"
  settings["CLANG_ENABLE_MODULES"] = "YES"
  settings["ENABLE_HARDENED_RUNTIME"] = "YES"
  settings["CODE_SIGN_STYLE"] = "Automatic"
  settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["MARKETING_VERSION"] = "0.1.0"
  settings["OTHER_LDFLAGS"] = [
    "$(inherited)",
    "-lc++",
    "-lresolv"
  ]
  settings["LIBRARY_SEARCH_PATHS"] = [
    "$(inherited)",
    "$(PROJECT_DIR)/rust/target/universal/release"
  ]
end

tests = project.new_target(
  :unit_test_bundle,
  "TokPeekTests",
  :osx,
  "14.0"
)

kit_sources = Dir[
  File.join(project_root, "Sources/TokPeekKit/*.swift")
].sort
test_sources = Dir[
  File.join(project_root, "Tests/TokPeekKitTests/*.swift")
].sort

kit_sources.each do |source_path|
  relative_path = source_path.delete_prefix("#{project_root}/Sources/")
  reference = sources_group.files.find { |file| file.path == relative_path }
  reference ||= sources_group.new_file(relative_path)
  tests.source_build_phase.add_file_reference(reference)
end

test_sources.each do |source_path|
  relative_path = source_path.delete_prefix("#{project_root}/Tests/")
  reference = tests_group.new_file(relative_path)
  tests.source_build_phase.add_file_reference(reference)
end

tests.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.tokpeek.tests"
  settings["GENERATE_INFOPLIST_FILE"] = "YES"
  settings["SWIFT_STRICT_CONCURRENCY"] = "complete"
  settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] =
    "$(inherited) XCODE_PROJECT"
  settings["CODE_SIGNING_ALLOWED"] = "NO"
  settings["TEST_HOST"] = ""
end

project.predictabilize_uuids
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as(project_path, "TokPeek", true)

puts "Generated #{project_path}"
