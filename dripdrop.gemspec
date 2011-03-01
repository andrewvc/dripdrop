# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "dripdrop/version"

Gem::Specification.new do |s|
  s.name        = "dripdrop"
  s.version     = DripDrop::VERSION
  s.platform    = Gem::Platform::CURRENT
  s.authors     = ["Andrew Cholakian"]
  s.email       = ["andrew@andrewvc.com"]
  s.homepage    = "https://github.com/andrewvc/dripdrop"
  s.summary     = %q{Evented framework for ZeroMQ and EventMachine Apps.}
  s.description = %q{Evented framework for ZeroMQ and EventMachine Apps.}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]

  s.rubyforge_project = "dripdrop"

  s.add_dependency "eventmachine", ">= 0.12.10"
  s.add_dependency "em-websocket", ">= 0"
  s.add_dependency "em-zeromq", ">= 0.2.0"
  if s.platform.os == "java"
    s.add_dependency "json", ">= 1.5.1" 
  else
    s.add_dependency "yajl-ruby", ">= 0.8.1"
  end
  s.add_development_dependency "rspec", ">= 2.4.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

