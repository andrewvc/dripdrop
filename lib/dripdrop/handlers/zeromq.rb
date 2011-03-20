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
    attr_reader :connection

    def initialize(opts={})
      @opts         = opts
      @connection   = nil
      @msg_format   = opts[:msg_format] || :dripdrop
      @message_class = @opts[:message_class] || DripDrop.default_message_class
    end

    def add_connection(connection)
      @connection = connection
    end

    def read_connection
      @connection
    end

    def write_connection
      @connection
    end

    def on_receive(msg_format=:dripdrop,&block)
      @recv_cbak = block
      self
    end
     
    def on_recv(*args,&block)
      $stderr.write "DripDrop Warning :on_recv is deprecated in favor of :on_receive"
      on_receive(*args,&block)
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
      @send_queue_enabled = false
    end

    def on_writable(conn)
      unless @send_queue.empty?
        message = @send_queue.shift

        conn.send_msg(*message)
      else
        conn.deregister_writable if @send_queue_enabled
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
      
      self.write_connection.register_writable if @send_queue_enabled
         
      EM::next_tick {
        on_writable(self.write_connection)
      }
    end
  end

  module ZMQReadableHandler
    attr_accessor :message_class
     
    def decode_message(msg)
      @message_class.decode(msg)
    end

    def on_readable(socket, messages)
      begin
        case @msg_format
        when :raw
          @recv_cbak.call(messages)
        when :dripdrop
          if messages.length > 1
            raise "Expected message in one part for #{self.inspect}, got #{messages.map(&:copy_out_string)}"
          end
          
          body  = messages.shift.copy_out_string
          @recv_cbak.call(decode_message(body))
        else
          raise "Unknown message format '#{@msg_format}'"
        end
      rescue StandardError => e
        handle_error(e)
      end
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
      begin
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
      rescue StandardError => e
        handle_error(e)
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
      dd_message = dd_messagify(message,@message_class)
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
        begin
          if messages.length < 3
            raise "Expected message in at least 3 parts, got #{messages.map(&:copy_out_string).inspect}"
          end
           
          message_strings = messages.map(&:copy_out_string)
          
          # parse the message into identities, delimiter and body
          identities = []
          delimiter  = nil
          body       = nil
          # It's an identitiy if it isn't an empty string
          # Once we hit the delimiter, we know the rest after is the body
          message_strings.each_with_index do |ms,i|
            unless ms.empty?
              identities << ms
            else
              delimiter = ms
               
              unless message_strings.length == i+2
                raise "Expected body in 1 part got '#{message_strings.inspect}'"
              end
               
              body  = message_strings[i+1]
              break
            end
          end
          
          raise "Received xreq message with no body!" unless body
          message    = decode_message(body)
          raise "Received nil message! #{body}" unless message
          seq        = message.head[SEQ_CTR_KEY]
          response   = ZMQXRepHandler::Response.new(self,identities,seq,@message_class)
          @recv_cbak.call(message,response) if @recv_cbak
        rescue StandardError => e
          handle_error(e)
        end
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
    
    def initialize(xrep,identities,seq,message_class)
      @xrep = xrep
      @seq  = seq
      @identities    = identities
      @message_class = message_class
    end
    
    def send_message(message)
      dd_message = dd_messagify(message,@message_class)
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

      # should never be handled by the user
      self.on_receive do |message|
        begin
          seq = message.head[SEQ_CTR_KEY]
          raise "Missing Seq Counter" unless seq
          promise = @promises.delete(seq)
          promise.call(message) if promise
        rescue StandardError => e
          handle_error(e)
        end
      end
    end

    def send_message(message,&block)
      begin
        dd_message = dd_messagify(message,@message_class)
        if dd_message.is_a?(DripDrop::Message)
          @seq_counter += 1
          dd_message.head[SEQ_CTR_KEY] = @seq_counter
          @promises[@seq_counter] = block if block
          message = dd_message
        end
      rescue StandardError => e
        handle_error(e)
      end
      super(['', message.encoded])
    end

    def on_readable(socket, messages)
      begin
        # Strip out empty delimiter
        super(socket, messages[1..-1])
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
