Gem::Specification.new do |spec|
  spec.name          = 'pow'
  spec.version       = '0.0.1'
  spec.authors       = ['Kasumi Hanazuki']
  spec.email         = ['kasumi@rollingapple.net']

  spec.summary       = %q{Manage PowerDNS zones with Ruby DSL.}
  spec.description   = %q{Manage PowerDNS zones with Ruby DSL.}
  spec.homepage      = 'https://github.com/hanazuki/pow'
  spec.license       = 'MIT'

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split(?\0).reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'pdns_api'
  spec.add_dependency 'thor'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
