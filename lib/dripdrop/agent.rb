require 'rubygems'
require 'zmq'
require 'bert'

class DripDrop
  class Agent
    attr_reader :address, :context, :socket
    def initialize(address)
      @address = address
      @context = ZMQ::Context.new(1)
      @socket  = @context.socket(ZMQ::PUB)
      @socket.connect(@address)
    end

    def send_message(name,content)
      puts @socket.send(Message.new(name,content).encoded, 0)
    end
  end
end
