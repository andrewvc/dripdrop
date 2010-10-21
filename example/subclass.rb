require 'dripdrop'
Thread.abort_on_exception = true

#We will create a subclass of the Message class
#which will add a timestamp to the header every
#time it is passed around

#First our subclass

class TimestampedMessage < DripDrop::Message
  def self.create_message(*args)
    obj = super
    obj.head[:timestamps] = []
    obj.head[:timestamps] << Time.now
    obj
  end

  def self.recreate_message(*args)
    obj = super
    obj.head[:timestamps] << Time.now.to_s
    obj
  end
end

#Define our handlers
#We'll create a batch of 5 push/pull queues them to
#show the timestamp array getting larger
#as we go along

DripDrop.default_message_class = TimestampedMessage

node = DripDrop::Node.new do
  push1 = zmq_push("tcp://127.0.0.1:2201", :bind)
  push2 = zmq_push("tcp://127.0.0.1:2202", :bind)

  pull1 = zmq_pull("tcp://127.0.0.1:2201", :connect)
  pull2 = zmq_pull("tcp://127.0.0.1:2202", :connect)

  pull1.on_recv do |msg|
    puts "Pull 1 #{msg.head}"
    sleep 1
    push2.send_message(msg)
  end

  pull2.on_recv do |msg|
    puts "Pull 2 #{msg.head}"
  end

  push1.send_message(TimestampedMessage.create_message(:name => 'test', :body => "Hello there"))
end

node.start
sleep 5
node.stop
