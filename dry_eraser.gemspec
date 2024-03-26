require_relative "lib/dry_eraser/version"

Gem::Specification.new do |spec|
  spec.name = "dry_eraser"
  spec.version = DryEraser::VERSION
  spec.authors = ["Justin Searls"]
  spec.email = ["searls@gmail.com"]

  spec.summary = "Like Active Record's validation feature, but for destroying models"
  spec.homepage = "https://github.com/searls/dry_eraser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "railties", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
end
