Kernel.load File.dirname(__FILE__) + '/lib/net/vnc/version.rb'

PKG_NAME = 'ruby-vnc'
PKG_VERSION = Net::VNC::VERSION

Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = %q{Ruby VNC library.}
  s.description = %q{A library which implements the client VNC protocol to control VNC servers.}
  s.authors = ['Charles Lowe']
  s.email = %q{aquasync@gmail.com}
  s.homepage = %q{https://github.com/aquasync/ruby-vnc}
  s.license = %q{MIT}
  s.rubyforge_project = %q{ruby-vnc}

  # none yet
  #s.executables = ['oletool']
  s.files  = ['Rakefile', 'README.rdoc', 'COPYING', 'Changelog.rdoc', 'data/keys.yaml']
  s.files += Dir.glob('lib/**/*.rb')
  s.files += Dir.glob('spec/*_spec.rb')
  # is there an rspec equivalent?
  #s.test_files = FileList['test/test_*.rb']

  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc', 'Changelog.rdoc']
  s.rdoc_options += [
    '--main', 'README.rdoc',
    '--title', "#{PKG_NAME} documentation",
    '--tab-width', '2'
  ]

  s.add_development_dependency 'rspec', '~> 3.7'
  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'simplecov', '~> 0.16'
end
