# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ridoku/version'

Gem::Specification.new do |spec|
  spec.name          = "ridoku"
  spec.version       = Ridoku::VERSION
  spec.authors       = ["Terry Meacham","Joel Clay"]
  spec.email         = ["zv1n.fire@gmail.com","ra3don92@gmail.com"]
  spec.description   = %q{Ridoku: OpsWork management CLI.}
  spec.summary       = %q{Ridoku: OpsWork management CLI.}
  spec.homepage      = "http://ridoku-cli.blogspot.com"
  spec.license       = "BSD 3-clause"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = ['ridoku', 'rid']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'aws-sdk', '~> 1.50'
  spec.add_runtime_dependency 'rugged', '~> 0.21'
  spec.add_runtime_dependency 'json', '~> 1.8'
  spec.add_runtime_dependency 'rest-client', '~> 1.7'
  spec.add_runtime_dependency 'require_all', '~> 1.3'
  spec.add_runtime_dependency 'activesupport', '~> 4.1'
  spec.add_runtime_dependency 'activesupport-inflector', '~> 0'


  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", '~> 0'
end
