#!/usr/bin/env ruby
require 'dripdrop/publisher'
require 'dripdrop/collector'
require 'dripdrop/mlogger'
require 'dripdrop/agent'

#ZMQ Forwarder, for aggregating messages from app servers
forwarder = DripDrop::Collector.new('tcp://127.0.0.1:2900','tcp://127.0.0.1:2901',
                                    :sub_opts => {:socket_ctype => :bind})
#Forwarder -> WebSocket bridge
publisher = DripDrop::Publisher.new('tcp://127.0.0.1:2901','ws://127.0.0.1:2902')
#Forwarder -> MongoDB Persistence
mlogger   = DripDrop::MLogger.new('tcp://127.0.0.1:2901')

forwarder.debug = publisher.sub_collector.debug = mlogger.sub_collector.debug = true

[forwarder,publisher,mlogger].each do |collector|
  puts "Init #{collector.class}" and $stdout.flush
  Process.fork do
    collector.run.join
  end
end
puts "Running!"

#Heartbeat
Thread.new do
  agent = DripDrop::Agent.new('tcp://127.0.0.1:2900')
  print "Heartbeat: "
  loop do
    agent.send_message('_dripdrop/heartbeat', :head => {:timestamp => Time.now.to_i})
     print '.'
    sleep 1
  end
end

#Trap INT because em-websocket (used by publisher) likes to block sigint 
trap("INT") do
  puts "Shutting Down..."
  exit
end

Process.wait
