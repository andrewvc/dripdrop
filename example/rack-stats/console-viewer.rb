#!/usr/bin/env ruby
require 'rubygems'
require 'dripdrop/node'

###
### Subscribe to a ZMQ Pub socket and output to console
###

sub_addr = ARGV[0]

DripDrop::Node.new do |node|
  #Setup the ZMQ Sub Socket
  node.zmq_subscribe(sub_addr).on_recv do |message|
    puts "Recv: #{message.inspect}"
  end
end.join
