require 'rubygems'
require 'dripdrop/agent'

agent = DripDrop::Agent.new('tcp://127.0.0.1:2900')

loop do
  #Test is the message name, this is the first part of the 0MQ message, used for filtering
  #at the 0MQ sub socket level, :head is always a hash,  :body is freeform
  #EVERYTHING must be serializable to BERT
  agent.send_message('test', :body => 'hello', :head => {:key => 'value'})
  puts "SEND"
  sleep 1
end
