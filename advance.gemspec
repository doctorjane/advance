
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "advance/version"

Gem::Specification.new do |spec|
  spec.name          = "advance"
  spec.version       = Advance::VERSION
  spec.authors       = ["janemacfarlane"]
  spec.email         = ["jfmacfarlane@lbl.gov"]

  spec.summary       = %q{A framework for building data transformation pipelines}
  spec.description   = %q{Advance allows you to concisely script your
data transformation process and to
incrementally build and easily debug that process.
Each data transformation is a step and the results of each
step become the input to the next step.
}
  spec.homepage      = "https://github.com/doctorjane/advance"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "team_effort"
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
