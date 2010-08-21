require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "dripdrop"
    gem.summary = %Q{0MQ App Stats}
    gem.description = %Q{0MQ App stats}
    gem.email = "andrew@andrewvc.com"
    gem.homepage = "http://github.com/andrewvc/dripdrop"
    gem.authors = ["Andrew Cholakian"]
    gem.add_dependency('ffi')
    gem.add_dependency('ffi-rzmq')
    gem.add_dependency('zmqmachine')
    gem.add_dependency('bert')
    gem.add_dependency('json')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "dripdrop #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
