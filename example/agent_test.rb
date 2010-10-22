##
##TODO: This badly needs to be rewritten
##

require 'rubygems'
require 'dripdrop/agent'

agent = DripDrop::Agent.new(ZMQ::PUB,'tcp://127.0.0.1:2900',:connect)

loop do
  agent.send_message('test', :body => 'hello', :head => {:key => 'value'})
  puts "SEND"
  sleep 1
end
