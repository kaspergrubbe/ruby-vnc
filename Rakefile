require 'rake'
require 'spec/rake/spectask'

spec = eval File.read('ruby-vnc.gemspec')

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

