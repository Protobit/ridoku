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

  spec.add_dependency 'aws-sdk'
  spec.add_dependency 'rugged'
  spec.add_dependency 'json'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'require_all'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'activesupport-inflector'


  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
