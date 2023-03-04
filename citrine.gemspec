# frozen_string_literal: true

require_relative "lib/citrine/version"

Gem::Specification.new do |spec|
  spec.name = "citrine"
  spec.version = Citrine::VERSION
  spec.authors = ["Chi Man Lei"]
  spec.email = ["chimanlei@gmail.com"]

  spec.summary = "Actor-based service api framework"
  spec.description = "Actor-based service api framework"
  spec.homepage = ""
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"
  # spec.required_ruby_version = ">= 2.5.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "celluloid", "~> 0.17.4"
  spec.add_runtime_dependency "reel", ">= 0.6.1"
  spec.add_runtime_dependency "sequel", ">= 5.65.0"
  spec.add_runtime_dependency "http", "~> 5.1.1"
  spec.add_runtime_dependency "sinatra", ">= 3.0.5"
  spec.add_runtime_dependency "sinatra-contrib", ">=3.0.5"
  spec.add_runtime_dependency "rack", ">= 2.0.5"
end
