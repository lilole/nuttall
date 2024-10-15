# frozen_string_literal: true

version = File.read(File.expand_path("VERSION", __dir__)).strip
base_url = "https://guthub.com/lilole/nuttall"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "nuttall"
  s.version     = version
  s.summary     = "Automated self-hosted industrial strength logging services."
  s.description = "The basic logger with encrypted log storage, and client SDKs."

  s.required_ruby_version = ">= 3.2.0"

  s.license = "Apache-2.0"

  s.author   = "Dan Higgins"
  s.email    = "dan@danamis.com"
  s.homepage = "#{base_url}/wiki"

  s.files        = Dir["CHANGELOG.md", "README.md", "LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  s.require_path = "lib"

  s.bindir      = "exe"
  s.executables = ["nuttall"]

  s.rdoc_options << "--exclude" << "."

  s.metadata = {
    "bug_tracker_uri"   => "#{base_url}/issues",
    "changelog_uri"     => "#{base_url}/blob/v#{version}/CHANGELOG.md",
    "documentation_uri" => "#{base_url}/wiki",
    "source_code_uri"   => "#{base_url}/tree/v#{version}"
  }

  s.add_dependency "zeitwerk", "~> 2.6"

  #s.add_development_dependency "zzz", "~> zzz"
end
