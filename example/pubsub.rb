require 'rubygems'
require 'dripdrop/node'
Thread.abort_on_exception = true

#Define our handlers
DripDrop::Node.new do
  route :pub,  :zmq_publish,   'tcp://localhost:2200', :bind
  route :sub1, :zmq_subscribe, pub.address, :connect, :topic_filter => /[13579]$/
  route :sub2, :zmq_subscribe, pub.address, :connect, :topic_filter => /[02468]$/
  route :sub3, :zmq_subscribe, pub.address, :connect
    
  sub1.on_recv do |message|
    puts "Receiver 1 #{message.inspect}"
  end

  sub2.on_recv do |message|
    puts "Receiver 2 #{message.inspect}"
  end

  sub3.on_recv do |message|
    puts "Receiver 3 #{message.inspect}"
  end
  
  zm_reactor.periodical_timer(500) do
    puts "Sending!"
    #Sending a hash as a message implicitly transforms it into a DripDrop::Message
    pub.send_message(:name => Time.now.to_i.to_s, :body => 'Test Payload')
  end
end.start! #Start the reactor and block until complete
