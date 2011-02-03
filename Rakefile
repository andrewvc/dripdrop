require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "dripdrop"
    gem.summary = %Q{Evented framework for ZeroMQ and EventMachine Apps.}
    gem.description = %Q{Evented framework for ZeroMQ and EventMachine Apps. }
    gem.email = "andrew@andrewvc.com"
    gem.homepage = "http://github.com/andrewvc/dripdrop"
    gem.authors = ["Andrew Cholakian"]
    gem.add_dependency('ffi-rzmq', '>= 0.7.1')
    gem.add_dependency('eventmachine', '>= 0.12.10')
    gem.add_dependency('em-websocket')
    gem.add_dependency('thin')
    gem.add_dependency('em-zeromq', '>= 0.1.2')
    gem.add_dependency('msgpack')
    gem.add_dependency('yajl-ruby')
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
