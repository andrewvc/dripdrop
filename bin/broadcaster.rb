require 'rubygems'
require 'ffi-rzmq'
require 'zmqmachine'

class Broadcaster
  attr_reader :messages
  
  def initialize(context)
    @context = context
    @messages = []
  end
  
  def on_attach(socket)
    puts "Attaching"
    address = ZM::Address.new '127.0.0.1', 5555, :tcp
    rc = socket.bind(address)
    @context.periodical_timer(1000) do
      socket.send_message_string("The time is #{Time.now}")
    end
  end
  
  def on_writable(socket)

  end
end

ZM::Reactor.new(:test).run do |context|
  broadcaster = Broadcaster.new(context)
  context.pub_socket broadcaster
  puts "Reactor Started"
end.join

puts "Ended"
