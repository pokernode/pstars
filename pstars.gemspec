# frozen_string_literal: true

require_relative 'lib/pstars/version'

Gem::Specification.new do |spec|
  spec.name          = 'pstars'
  spec.version       = PStars::VERSION
  spec.authors       = ['']
  spec.email         = ['']

  spec.summary       = 'Poker hand history parser and stats'
  spec.description   = spec.summary
  spec.license       = 'MIT'

  spec.files         = Dir.glob('bin/*') + Dir.glob('lib/**/*') + %w[LICENSE README]
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7'

  spec.add_dependency 'json'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
end
