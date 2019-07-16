require File.expand_path('../lib/net/vnc/version.rb', __FILE__)

pkg_name = 'ruby-vnc'
pkg_version = Net::VNC::VERSION

Gem::Specification.new do |s|
  s.name = pkg_name
  s.version = pkg_version
  s.summary = 'Ruby VNC library.'
  s.description = 'A library which implements the client VNC protocol to control VNC servers.'
  s.authors = ['Charles Lowe']
  s.email = 'aquasync@gmail.com'
  s.homepage = 'https://github.com/aquasync/ruby-vnc'
  s.license = 'MIT'

  # none yet
  #s.executables = ['oletool']
  s.files  = ['Rakefile', 'README.rdoc', 'COPYING', 'Changelog.rdoc', 'data/keys.yaml']
  s.files += Dir.glob('lib/**/*.rb')
  s.files += Dir.glob('spec/*_spec.rb')
  # is there an rspec equivalent?
  #s.test_files = FileList['test/test_*.rb']

  s.extra_rdoc_files = ['README.rdoc', 'Changelog.rdoc']
  s.rdoc_options += [
    '--main', 'README.rdoc',
    '--title', "#{pkg_name} documentation",
    '--tab-width', '2'
  ]

  s.add_runtime_dependency 'vncrec', '~> 1.0.6'
  s.add_runtime_dependency 'chunky_png', '~> 1.3.0'

  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'rspec', '~> 3.7'
  s.add_development_dependency 'simplecov', '~> 0.16'
  s.add_development_dependency 'image_size', '~> 2.0'
end
