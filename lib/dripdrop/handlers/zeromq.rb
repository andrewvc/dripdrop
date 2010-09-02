require 'ffi-rzmq'

class DripDrop
  class ZMQSubHandler
    def initialize(address,zm_reactor,opts={},&block)
      @address      = address
      @socket_ctype = opts[:socket_ctype] # :bind or :connect
      @debug        = opts[:debug]
      @recv_cbak    = block
      @zm_reactor   = zm_reactor
    end
    
    def on_attach(socket)
      if @socket_ctype == :bind
        socket.bind(@address)
      else
        socket.connect(@address)
      end
      socket.subscribe('')
    end
    
    def on_readable(socket, messages)
      if @msg_format == :raw
        @recv_cbak.call(messages)
      else
        topic = messages.shift.copy_out_string
        body  = messages.shift.copy_out_string
        msg   = @recv_cbak.call(DripDrop::Message.decode(body))
      end
    end

    def on_recv(msg_format=:dripdrop,&block)
      @msg_format = msg_format 
      @recv_cbak = block
      self
    end
  end
   
  class ZMQPubHandler
    def initialize(address,zm_reactor,opts={})
      @address      = address
      @socket_ctype = opts[:socket_ctype]
      @debug        = opts[:debug]
      @zm_reactor   = zm_reactor
      
      #Buffer messages here till on_writable
      @send_queue = []
    end
    
    def on_attach(socket)
      @socket = socket
       
      if @socket_ctype == :connect
        socket.connect(@address.to_s)
      else
        socket.bind(@address.to_s)
      end
    end
    
    #Send any messages buffered in @send_queue
    def on_writable(socket)
      unless @send_queue.empty?
        topic, message = @send_queue.shift
        socket.send_message_string(topic, ZMQ::SNDMORE)
        socket.send_message_string(message)
      else
        @zm_reactor.deregister_writable(socket)
      end
    end
    
    #Sends a message along
    def send_message(message)
      if message.is_a?(DripDrop::Message)
        @send_queue.push([message.name, message.encoded])
        @zm_reactor.register_writable(@socket)
      else
        @send_queue.push(message)
      end
    end
  end
end
