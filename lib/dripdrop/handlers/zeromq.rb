require 'ffi-rzmq'

class DripDrop
  class ZMQBaseHandler
    attr_reader :address, :socket_ctype, :socket
    
    def initialize(address,zm_reactor,socket_ctype,opts={})
      @address      = address
      @zm_reactor   = zm_reactor
      @socket_ctype = socket_ctype # :bind or :connect
      @debug        = opts[:debug] # TODO: Start actually using this
    end
    
    def on_attach(socket)
      @socket = socket
      if    @socket_ctype == :bind
        socket.bind(@address)
      elsif @socket_ctype == :connect
        socket.connect(@address)
      else
        raise "Unsupported socket ctype '#{@socket_ctype}'. Expected :bind or :connect"
      end
    end
     
    def on_recv(msg_format=:dripdrop,&block)
      @msg_format = msg_format 
      @recv_cbak = block
      self
    end

    private
  
    # Normalize Hash objs and DripDrop::Message objs into DripDrop::Message objs
    def dd_messagify(message)
      if message.is_a?(Hash)
        return DripDrop::Message.new(message[:name], :head => message[:head], 
                                                     :body => message[:body])
      elsif message.is_a?(DripDrop::Message)
        return message
      else
        return message
      end
    end
  end

  module ZMQWritableHandler
    def initialize(*args)
      super(*args)
      @send_queue = []
    end

    def on_writable(socket)
      unless @send_queue.empty?
        message = @send_queue.shift
        
        num_parts = message.length
        message.each_with_index do |part,i|
          # Set the multi-part flag unless this is the last message
          multipart_flag = i + 1 < num_parts ? true : false
          
          if part.class == ZMQ::Message
            socket.send_message(part, multipart_flag)
          else
            if part.class == String
              socket.send_message_string(part, multipart_flag)
            else
              raise "Can only send Strings, not #{part.class}: #{part}"
            end
          end
        end
      else
        @zm_reactor.deregister_writable(socket)
      end
    end

    # Sends a message, accepting either a DripDrop::Message,
    # a hash that looks like a DripDrop::Message (has keys :name, :head, :body),
    # or your own custom messages. Custom messages should either be a String, or
    # for multipart messages, an Array of String objects.
    def send_message(message)
      dd_message = dd_messagify(message)
      if dd_message.is_a?(DripDrop::Message)
        @send_queue.push([dd_message.encoded])
      elsif message.class == Array
        @send_queue.push(message)
      else
        @send_queue.push([message])
      end
      @zm_reactor.register_writable(@socket)
    end
  end
  
  module ZMQReadableHandler
    def initialize(*args)
      super(*args)
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
          puts "Expected pub/sub message to come in two parts, not #{messages.length}: #{messages.inspect}" 
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
      dd_message = dd_messagify(message)
      if dd_message.is_a?(DripDrop::Message)
        super([dd_message.name, dd_message.encoded])
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
        message = DripDrop::Message.decode(body)
        seq     = message.head['_dripdrop/x_seq_counter']
        @recv_cbak.call(identities,seq,message)
      else
        super(socket,messages)
      end
    end

    def send_message(identities,seq,message)
      if message.is_a?(DripDrop::Message)
        message.head['_dripdrop/x_seq_counter'] = seq
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
