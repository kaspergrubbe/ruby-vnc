require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

require File.dirname(__FILE__) + '/lib/net/vnc/version'

PKG_NAME = 'ruby-vnc'
PKG_VERSION = Net::VNC::VERSION

task :default => :spec

desc 'Run all specs'
Spec::Rake::SpecTask.new :spec do |t|
	t.spec_opts = ['--format specdoc --colour']
end

desc 'Run all specs and generate html spec document'
namespace :spec do
	Spec::Rake::SpecTask.new :html do |t|
		t.spec_opts = ['--format html:spec.html']
	end
end

desc 'Run all specs and generate coverage'
Spec::Rake::SpecTask.new :rcov do |t|
	t.rcov = true
	t.rcov_opts = ['--exclude', 'spec']
	t.rcov_opts << '--xrefs'
	t.rcov_opts << '--text-report'
end

namespace :rcov do
	RCov::VerifyTask.new :verify => :rcov do |t|
		t.threshold = 100.0
		t.index_html = 'coverage/index.html'
	end
end

Rake::RDocTask.new do |t|
	t.rdoc_dir = 'doc'
	t.rdoc_files.include 'lib/**/*.rb'
	t.rdoc_files.include 'README'
	t.title = "#{PKG_NAME} documentation"
	t.options += %w[--line-numbers --inline-source --tab-width 2]
	t.main = 'README'
end

spec = Gem::Specification.new do |s|
	s.name = PKG_NAME
	s.version = PKG_VERSION
	s.summary = %q{Ruby VNC library.}
	s.description = %q{A library which implements the client VNC protocol to control VNC servers.}
	s.authors = ['Charles Lowe']
	s.email = %q{aquasync@gmail.com}
	# not yet registered
	#s.homepage = %q{http://code.google.com/p/ruby-vnc}
	#s.rubyforge_project = %q{ruby-vnc}

	# none yet
	#s.executables = ['oletool']
	s.files  = ['Rakefile', 'README', 'ChangeLog', 'data/keys.yaml']
	s.files += FileList['lib/**/*.rb']
	s.files += FileList['spec/*_spec.rb']
	# is there an rspec equivalent?
	#s.test_files = FileList['test/test_*.rb']

	s.has_rdoc = true
	s.rdoc_options += [
		'--main', 'README',
		'--title', "#{PKG_NAME} documentation",
		'--tab-width', '2'
	]
end

Rake::GemPackageTask.new(spec) do |t|
	t.gem_spec = spec
	t.need_tar = false
	t.need_zip = false
	t.package_dir = 'build'
end

