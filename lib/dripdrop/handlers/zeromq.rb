require 'ffi-rzmq'
require 'em-zeromq'

class DripDrop
  SEQ_CTR_KEY = '_dd/xctr'
  
  #Setup the default message class handler first
  class << self
    attr_accessor :default_message_class

    DripDrop.default_message_class = DripDrop::Message
  end

  class ZMQBaseHandler < BaseHandler
    attr_accessor :connection

    def initialize(opts={})
      @opts         = opts
      @connection   = nil
      @msg_format   = opts[:msg_format] || :dripdrop
    end

    def on_recv(msg_format=:dripdrop,&block)
      @msg_format = msg_format
      @recv_cbak = block
      self
    end

    def address
      self.connection.address
    end

    #Triggered after a handler is setup
    def post_setup; end
  end

  module ZMQWritableHandler
    def initialize(*args)
      super(*args)
      @send_queue = []
      @send_queue_enabled = true
    end

    def on_writable(socket)
      unless @send_queue.empty?
        message = @send_queue.shift

        num_parts = message.length
        message.each_with_index do |part,i|
          # Set the multi-part flag unless this is the last message
          flags = (i + 1 < num_parts ? ZMQ::SNDMORE : 0) + ZMQ::NOBLOCK

          if part.class == ZMQ::Message
            socket.send(part, flags)
          else
            if part.class == String
              socket.send_string(part, flags)
            else
              $stderr.write "Can only send Strings, not #{part.class}: #{part}" if @debug
            end
          end
        end
      else
        @connection.deregister_writable if @send_queue_enabled
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
        
      
      if @send_queue_enabled
        @connection.register_writable
         
        # Not sure why this is necessary, this is likely a bug in em-zeromq
        on_writable(@connection.socket)
      else
        on_writable(@connection.socket)
      end
    end
  end

  module ZMQReadableHandler
    attr_accessor :message_class

    def initialize(*args)
      super(*args)
      @message_class = @opts[:message_class] || DripDrop.default_message_class
    end

    def decode_message(msg)
      @message_class.decode(msg)
    end

    def on_readable(socket, messages)
      case @msg_format
      when :raw
        @recv_cbak.call(messages)
      when :dripdrop
        raise "Expected message in one part" if messages.length > 1
        body  = messages.shift.copy_out_string
        @recv_cbak.call(decode_message(body))
      else
        raise "Unknown message format '#{@msg_format}'"
      end
    end

    def post_setup
      @connection.register_readable
    end
  end

  class ZMQSubHandler < ZMQBaseHandler
    include ZMQReadableHandler

    attr_accessor :topic_filter
    
    def initialize(*args)
      super(*args)
      self.topic_filter = @opts[:topic_filter]
    end

    def on_readable(socket, messages)
      if @msg_format == :dripdrop
        unless messages.length == 2
          return false
        end
        topic = messages.shift.copy_out_string
        if @topic_filter.nil? || topic.match(@topic_filter)
          body  = messages.shift.copy_out_string
          @recv_cbak.call(decode_message(body))
        end
      else
        super(socket,messages)
      end
    end

    def post_setup
      super
      @connection.socket.setsockopt(ZMQ::SUBSCRIBE, '')
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
        body       = messages.last.copy_out_string
        message    = decode_message(body)
        seq        = message.head[SEQ_CTR_KEY]
        response   = ZMQXRepHandler::Response.new(self, identities,seq)
        @recv_cbak.call(message,response)
      else
        super(socket,messages)
      end
    end

    def send_message(message,identities,seq)
      if message.is_a?(DripDrop::Message)
        message.head[SEQ_CTR_KEY] = seq
         
        resp  = identities + ['', message.encoded]
        super(resp)
      else
        resp  = identities + ['', message]
        super(resp)
      end
    end
  end
  
  class ZMQXRepHandler::Response < ZMQBaseHandler
    attr_accessor :xrep, :seq, :identities
    
    def initialize(xrep,identities,seq)
      @xrep = xrep
      @seq  = seq
      @identities = identities
    end
    
    def send_message(message)
      dd_message = dd_messagify(message)
      @xrep.send_message(dd_message,identities,seq)
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
        seq = message.head[SEQ_CTR_KEY]
        raise "Missing Seq Counter" unless seq
        promise = @promises.delete(seq)
        promise.call(message) if promise
      end
    end

    def send_message(message,&block)
      dd_message = dd_messagify(message)
      if dd_message.is_a?(DripDrop::Message)
        @seq_counter += 1
        dd_message.head[SEQ_CTR_KEY] = @seq_counter
        @promises[@seq_counter] = block if block
        message = dd_message
      end
      super(message)
    end

    def on_readable(socket, messages)
      # Strip out empty delimiter
      super(socket, messages[1..-1])
    end
  end
end
