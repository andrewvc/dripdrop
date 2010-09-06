require 'dripdrop/message'
#Check if we're in 1.8.7
unless defined?(RUBY_ENGINE)
  require 'zmq'
  ZMQGEM = :rbzmq
else
  require 'ffi-rzmq'
  ZMQGEM = :ffirzmq
end
require 'uri'
require 'bert'

class DripDrop
  #The Agent class is a simple ZMQ Pub client. It uses DripDrop::Message messages
  class Agent
    attr_reader :address, :context, :socket
    
    #address should be a string like tcp://127.0.0.1
    def initialize(sock_type,address)
      @context = ZMQ::Context.new(1)
      @socket  = @context.socket(sock_type)
      @socket.connect(address)
    end

    #Sends a DripDrop::Message to the socket
    def send_message(name,body,head={})
      message = DripDrop::Message.new(name,:body => body, :head => head).encoded
      if ZMQGEM == :rbzmq
        @socket.send name, ZMQ::SNDMORE
        @socket.send message
      else
        @socket.send_string name, ZMQ::SNDMORE
        @socket.send_string message
      end
    end
  end
end
