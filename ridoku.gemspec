# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ridoku/version'

Gem::Specification.new do |spec|
  spec.name          = "ridoku"
  spec.version       = Ridoku::VERSION
  spec.authors       = ["Terry Meacham"]
  spec.email         = ["zv1n.fire@gmail.com"]
  spec.description   = %q{Ridoku: OpsWork management CLI.}
  spec.summary       = %q{Ridoku: OpsWork management CLI.}
  spec.homepage      = "ridoku-cli.blogspot.com"
  spec.license       = "BSD 3-clause"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = ['ridoku']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
