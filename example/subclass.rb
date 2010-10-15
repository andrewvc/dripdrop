require 'dripdrop'
Thread.abort_on_exception = true

#We will create a subclass of the Message class
#which will add a timestamp to the header every
#time it is passed around

#First our subclass

class TimestampedMessage < DripDrop::Message
  def initialize(*args)
    super
    @head[:timestamps] ||= []
    @head[:timestamps] << Time.now
  end
end

#Define our handlers
#We'll create a batch of 5 push/pull queues them to
#show the timestamp array getting larger
#as we go along

DripDrop.default_message_class = TimestampedMessage

DripDrop::Node.new do
  push1 = zmq_push("tcp://127.0.0.1:2201", :bind)
  push2 = zmq_push("tcp://127.0.0.1:2202", :bind)
  push3 = zmq_push("tcp://127.0.0.1:2203", :bind)
  push4 = zmq_push("tcp://127.0.0.1:2204", :bind)
  push5 = zmq_push("tcp://127.0.0.1:2205", :bind)

  pull1 = zmq_pull("tcp://127.0.0.1:2201", :connect)
  pull2 = zmq_pull("tcp://127.0.0.1:2202", :connect)
  pull3 = zmq_pull("tcp://127.0.0.1:2203", :connect)
  pull4 = zmq_pull("tcp://127.0.0.1:2204", :connect)
  pull5 = zmq_pull("tcp://127.0.0.1:2205", :connect)

  #We'll switch out the message class for pull3 to show the difference
  pull3.message_class = DripDrop::Message

  pull1.on_recv do |msg|
    puts "Pull 1 #{msg.head}"
    sleep 1
    push2.send_message(msg)
  end

  pull2.on_recv do |msg|
    puts "Pull 2 #{msg.head}"
    sleep 1
    push3.send_message(msg)
  end

  #Remember that since we've switched this pull back to the standard
  #message class of DripDrop::Message there will be no timestamp change here
  pull3.on_recv do |msg|
    puts "Pull 3 #{msg.head}"
    sleep 1
    push4.send_message(msg)
  end

  pull4.on_recv do |msg|
    puts "Pull 4 #{msg.head}"
    sleep 1
    push5.send_message(msg)
  end

  pull5.on_recv do |msg|
    puts "Pull 5 #{msg.head}"
  end

  push1.send_message(:name => 'test', :body => "Hello there")
end.start! #Start the reactor and block until complete
