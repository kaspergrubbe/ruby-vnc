require 'rake'

task :default => :spec

desc 'Run all specs'
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

desc 'Run all specs and generate html spec document'
namespace :spec do
	RSpec::Core::RakeTask.new :html do |t|
		t.rspec_opts = ['--format html --out spec.html']
	end
end

require 'rdoc/task'

Rake::RDocTask.new do |t|
	t.rdoc_dir = 'doc'
	t.rdoc_files.include 'lib/**/*.rb'
	t.rdoc_files.include 'README'
	t.title = "ruby-vnc documentation"
	t.options += %w[--line-numbers --inline-source --tab-width 2]
	t.main = 'README'
end

require 'rubygems/package_task'

spec = eval File.read('ruby-vnc.gemspec')
Gem::PackageTask.new(spec) do |pkg|
	pkg.need_tar = false
	pkg.need_zip = false
	pkg.package_dir = 'build'
end

