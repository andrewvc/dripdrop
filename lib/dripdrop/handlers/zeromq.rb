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

  module ZMQWritableHandler
    def initialize(*args)
      super(*args)
      @send_queue = []
    end

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
      if message.class == DripDrop::Message
        @send_queue.push([message.encoded])
      elsif message.class == Array
        @send_queue.push(message)
      else
        @send_queue.push([message])
      end
      @zm_reactor.register_writable(@socket)
    end
  end
  
  module ZMQReadableHandler
    def initialize(*args,&block)
      super(*args)
      @recv_cbak = block
    end

    def on_readable(socket, messages)
      case @msg_format
      when :raw
        @recv_cbak.call(messages)
      when :dripdrop
        raise "Expected message in one part" if messages.length > 1
        body  = messages.shift.copy_out_string
        @recv_cbak.call(DripDrop::Message.decode(body))
      else
        raise "Unknown message format '#{@msg_format}'"
      end
    end
  end
  
  class ZMQSubHandler < ZMQBaseHandler
    include ZMQReadableHandler
    
    attr_reader :address, :socket_ctype
    
    def on_attach(socket)
      super(socket)
      socket.subscribe('')
    end

    def on_readable(socket, messages)
      if @msg_format == :dripdrop
        unless messages.length == 2
          puts "Expected pub/sub message to come in two parts #{self.inspect}" 
          return false
        end
        topic = messages.shift.copy_out_string
        body  = messages.shift.copy_out_string
        msg   = @recv_cbak.call(DripDrop::Message.decode(body))
      else
        super(socket,messages)
      end
    end
  end
  
  class ZMQPubHandler < ZMQBaseHandler
    include ZMQWritableHandler
    
    #Sends a message along
    def send_message(message)
      if message.is_a?(DripDrop::Message)
        @send_queue.push([message.name, message.encoded])
        @zm_reactor.register_writable(@socket)
      else
        super(message)
      end
    end
  end

  class ZMQPullHandler < ZMQBaseHandler
    include ZMQReadableHandler
    

  end

  class ZMQPushHandler < ZMQBaseHandler
    include ZMQWritableHandler
    
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

  class ZMQXRepHandler < ZMQBaseHandler
    include ZMQWritableHandler
    include ZMQReadableHandler
    
    def initialize(*args)
      super(*args)
    end
    
    def on_readable(socket,messages)
      if @msg_format == :dripdrop
        identities = messages[0..-2].map {|m| m.copy_out_string}
        body  = messages.last.copy_out_string
        msg   = DripDrop::Message.decode(body)
        @recv_cbak.call(identities,msg)
      else
        super(socket,messages)
      end
    end

    def send_message(identities,message)
      if message.is_a?(DripDrop::Message)
        @send_queue.push(identities + [message.encoded])
        @zm_reactor.register_writable(@socket)
      else
        super(message)
      end
    end
  end

  class ZMQXReqHandler < ZMQBaseHandler
    include ZMQWritableHandler
    include ZMQReadableHandler
    
    def initialize(*args)
      super(*args)
      #Used to keep track of responses
      @seq_counter = 0
      @promises = {}
      
      self.on_recv do |message|
        seq = message.head['_dripdrop/x_seq_counter']
        raise "Missing Seq Counter" unless seq
        promise = @promises.delete(seq)
        promise.call(message)
      end
    end
    
    def send_message(message,&block)
      if message.is_a?(DripDrop::Message)
        @seq_counter += 1
        message.head['_dripdrop/x_seq_counter'] = @seq_counter
        @promises[@seq_counter] = block
        super(message)
      end
    end
  end
end
