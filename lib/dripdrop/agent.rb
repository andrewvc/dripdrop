require 'dripdrop/message'
require 'zmq'
require 'bert'

class DripDrop
  #The Agent class is a simple ZMQ Pub client. It uses DripDrop::Message messages
  class Agent
    attr_reader :address, :context, :socket
    
    #address should be a string like tcp://127.0.0.1
    def initialize(address)
      @address = address
      @context = ZMQ::Context.new(1)
      @socket  = @context.socket(ZMQ::PUB)
      @socket.connect(@address)
    end

    #Sends a DripDrop::Message to the socket
    def send_message(name,body,head={})
      puts @socket.send(DripDrop::Message.new(name,:body => body, :head => head).encoded, 0)
    end
  end
end
