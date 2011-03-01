require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/rdoctask'
require 'dripdrop/version'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "dripdrop #{DripDrop::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
end
task :default => :spec
