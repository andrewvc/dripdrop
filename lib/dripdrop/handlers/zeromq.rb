require 'ffi-rzmq'

class DripDrop
  class ZMQBaseHandler
    attr_reader :address, :socket_ctype, :socket
    
    def initialize(address,zm_reactor,socket_ctype,opts={})
      @address      = address
      @zm_reactor   = zm_reactor
      @socket_ctype = socket_ctype # :bind or :connect
      @debug        = opts[:debug]
    end
    
    def on_attach(socket)
      @socket = socket
      if    @socket_ctype == :bind
        socket.bind(@address)
      elsif @socket_ctype == :connect
        socket.connect(@address)
      else
        raise "Unsupported socket ctype '#{@socket_ctype}'"
      end
    end
     
    def on_recv(msg_format=:dripdrop,&block)
      @msg_format = msg_format 
      @recv_cbak = block
      self
    end
  end

  class ZMQWritableHandler < ZMQBaseHandler
    def initialize(*args)
      super(*args)
      @send_queue = []
    end
  end
  
  class ZMQReadableHandler < ZMQBaseHandler
    def initialize(*args,&block)
      super(*args)
      @recv_cbak = block
    end
  end
  
  class ZMQSubHandler < ZMQReadableHandler
    attr_reader :address, :socket_ctype
    
    def on_attach(socket)
      super(socket)
      socket.subscribe('')
    end

    def on_readable(socket, messages)
      if    @msg_format == :raw
        @recv_cbak.call(messages)
      elsif @msg_format == :dripdrop
        unless messages.length == 2
          puts "Expected pub/sub message to come in two parts" 
          return false
        end
        topic = messages.shift.copy_out_string
        body  = messages.shift.copy_out_string
        msg   = @recv_cbak.call(DripDrop::Message.decode(body))
      else
        raise "Unsupported message format '#{@msg_format}'"
      end
    end
  end
    
  
  class ZMQPubHandler < ZMQWritableHandler
    #Send any messages buffered in @send_queue
    def on_writable(socket)
      unless @send_queue.empty?
        message = @send_queue.shift
        
        num_parts = message.length
        message.each_with_index do |part,i|
          multipart = i + 1 < num_parts ? true : false
          if part.class == ZMQ::Message
            socket.send_message(part, multipart)
          else
            socket.send_message_string(part, multipart)
          end
        end
      else
        @zm_reactor.deregister_writable(socket)
      end
    end
    
    #Sends a message along
    def send_message(message)
      if message.is_a?(DripDrop::Message)
        @send_queue.push([message.name, message.encoded])
      elsif message.is_a?(Array)
        @send_queue.push(message)
      else
        @send_queue.push([message])
      end
      @zm_reactor.register_writable(@socket)
    end
  end

  class ZMQPullHandler < ZMQReadableHandler
    def on_readable(socket, messages)
      if @msg_format == :raw
        @recv_cbak.call(messages)
      else
        body  = messages.shift.copy_out_string
        msg   = @recv_cbak.call(DripDrop::Message.decode(body))
      end
    end
  end

  class ZMQPushHandler < ZMQWritableHandler
    def on_writable(socket)
      unless @send_queue.empty?
        message = @send_queue.shift
        socket.send_message_string(message)
      else
        @zm_reactor.deregister_writable(socket)
      end
    end
    
    #Sends a message along
    def send_message(message)
      if message.is_a?(DripDrop::Message)
        @send_queue.push(message.encoded)
        @zm_reactor.register_writable(@socket)
      else
        @send_queue.push(message)
      end
    end
  end
end
