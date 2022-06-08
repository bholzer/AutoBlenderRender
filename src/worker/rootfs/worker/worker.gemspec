lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "worker/version"

Gem::Specification.new do |spec|
  spec.name          = "worker"
  spec.version       = Worker::VERSION
  spec.authors       = ["Brennan Holzer"]
  spec.email         = ["brennan.holzer@gmail.com"]

  spec.summary       = %q{gem for node renderer}
  #spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/bholzer/AutoBlenderRender"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/bholzer/AutoBlenderRender"
    #spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir['lib/**/*.rb'] + Dir['exe/*']
  spec.files += Dir['[A-Z]*'] + Dir['test/**/*']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_runtime_dependency "aws-sdk-s3", "~> 1.113.2"
  spec.add_runtime_dependency "aws-sdk-autoscaling", "~> 1.79.0"
  spec.add_runtime_dependency "aws-sdk-sqs", "~> 1.51.1"
end