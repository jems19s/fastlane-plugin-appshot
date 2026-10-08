lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fastlane/plugin/appshot/version"

Gem::Specification.new do |spec|
  spec.name          = "fastlane-plugin-appshot"
  spec.version       = Fastlane::Appshot::VERSION
  spec.author        = "Maksim Zhelezniakov"
  spec.email         = "48087000+jems19s@users.noreply.github.com"

  spec.summary       = "Frame fastlane snapshot captures with appshot and hand them to deliver"
  spec.homepage      = "https://github.com/jems19s/fastlane-plugin-appshot"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w[README.md LICENSE]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/jems19s/fastlane-plugin-appshot"
  spec.metadata["bug_tracker_uri"] = "https://github.com/jems19s/fastlane-plugin-appshot/issues"
  spec.required_ruby_version = ">= 3.0"

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency
end
