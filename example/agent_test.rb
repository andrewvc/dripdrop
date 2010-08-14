require '../lib/dripdrop/agent'
require '../lib/dripdrop/message'

agent = DripDrop::Agent.new('tcp://127.0.0.1:2900')

loop do
  agent.send_message('test', :body => 'hello')
  puts "SEND #{agent.address}"
  sleep 1
end
