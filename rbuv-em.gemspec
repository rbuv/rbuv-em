# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rbuv/em/version'

Gem::Specification.new do |spec|
  spec.name          = "rbuv-em"
  spec.version       = Rbuv::EM::VERSION
  spec.authors       = ["Hanfei Shen"]
  spec.email         = ["qqshfox@gmail.com"]
  spec.description   = %q{EventMachine compatibility for rbuv}
  spec.summary       = %q{EventMachine compatibility for rbuv}
  spec.homepage      = "https://github.com/rbuv/rbuv-em"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rbuv", ">= 0.0.5"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
