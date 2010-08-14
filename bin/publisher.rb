require '../lib/dripdrop/publisher'
require '../lib/dripdrop/message'

publisher = Publisher.new
puts "Starting"
publisher.run
puts "Done"
exit

@ws.onclose { puts "Connection closed" }
 @ws.onmessage { |msg|
           puts "Recieved message: #{msg}"
           ws.send({:type => 'tData', :data => 'hi'}.to_json)
         }
