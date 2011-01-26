require 'rubygems'
require 'websocket'
require 'dripdrop/message'

Thread.abort_on_exception = true

client = WebSocket.new('ws://127.0.0.1:8080')

Thread.new do
  while data = client.receive
    puts data
  end
end

i = 0
while sleep 1
  i += 1
  puts '.'
  client.send(DripDrop::Message.new('Client Broadcast', :body => i).json_encoded)
end
