require 'rubygems'
require 'yajl'

class DripDrop
  class WrongMessageClassError < StandardError; end
  # DripDrop::Message messages are exchanged between all tiers in the architecture
  # A Message is composed of a name, head, and body, and should be restricted to types that
  # can be readily encoded to JSON.
  # name: Any string
  # head: A hash containing anything (should be used for metadata)
  # body: anything you'd like, it can be null even
  #
  # Hashes, arrays, strings, integers, symbols, and floats are probably what you should stick to.
  # Internally, they're just stored using MsgPack, which is pretty much a super-fast, binary JSON
  #
  # The basic message format is built to mimic HTTP (s/url_path/name/). Why? Because I'm a dumb web developer :)
  # The name is kind of like the URL, its what kind of message this is, but it's a loose definition,
  # use it as you see fit.
  # head should be used for metadata, body for the actual data.
  # These definitions are intentionally loose, because protocols tend to be used loosely.
  class Message
     
    attr_accessor :name, :head, :body

    # Creates a new message.
    # example:
    #   DripDrop::Message.new('mymessage', 'head' => {:timestamp => Time.now},
    #     :body => {:mykey => :myval,  :other_key => ['complex']})
    def initialize(name,extra={})
      raise ArgumentError, "Message names may not be empty or null!" if name.nil? || name.empty?

      @head = extra[:head] || extra['head'] || {}
      raise ArgumentError, "Invalid head #{@head}. Head must be a hash!" unless @head.is_a?(Hash)
      @head['message_class'] = self.class.to_s

      @name = name
      @body = extra[:body] || extra['body']
    end

    # The encoded message, ready to be sent across the wire via ZMQ
    def encoded
      Yajl::Encoder.encode self.to_hash
    end

    # (Deprecated) Encodes the hash represntation of the message to JSON
    def json_encoded
      encoded
    end
    # (Deprecated, use json_encoded)
    def encode_json; json_encoded; end

    # Convert the Message to a hash like:
    # {'name' => @name, 'head' => @head, 'body' => @body}
    def to_hash
      {'name' => @name, 'head' => @head, 'body' => @body}
    end

    # Build a new Message from a hash that looks like
    #    {:name => name, :body => body, 'head' => head}
    def self.from_hash(hash)
      self.new(hash[:name] || hash['name'], 
               :head => hash[:head] || hash['head'],
               :body => hash[:body] || hash['body'])
    end

    def self.create_message(*args)
      case args[0]
        when Hash then self.from_hash(args[0])
        else self.new(args)
      end
    end

    def self.recreate_message(hash)
      raise ArgumentError, "Message missing head: #{hash.inspect}" unless hash['head']
      raise DripDrop::WrongMessageClassError, "Wrong message class #{hash['head']['message_class']} for #{self.to_s}" unless hash['head']['message_class'] == self.to_s
      self.from_hash(hash)
    end

    # Parses an already encoded string
    def self.decode(msg)
      return nil if msg.nil? || msg.empty?

      decoded = Yajl::Parser.parse(msg)
      self.recreate_message(decoded)
    end

    # (Deprecated). Use decode instead
    def self.parse(msg); self.decode(msg) end

    # (Deprecated) Decodes a string containing a JSON representation of a message
    def self.decode_json(str)
      self.decode(str)
    end
  end

  #Use of this "metaclass" allows for the automatic recognition of the message's
  #base class
  class AutoMessageClass < Message
    def initialize(*args)
      raise "Cannot create an instance of this class - please use create_message class method"
    end

    class << self
      attr_accessor :message_subclasses

      DripDrop::AutoMessageClass.message_subclasses = {'DripDrop::Message' => DripDrop::Message}

      def verify_args(*args)
        head =
          case args[0]
            when Hash
              az = args[0]
              az[:head] || az['head']
            else
              args[1]
          end
        raise ArgumentError, "Invalid head #{head.inspect}. Head must be a hash! (args: #{args.inspect})" unless head.is_a?(Hash)

        msg_class = head['message_class']
        unless DripDrop::AutoMessageClass.message_subclasses.has_key?(msg_class)
          raise ArgumentError, "Unknown AutoMessage message class #{msg_class}"
        end

        DripDrop::AutoMessageClass.message_subclasses[msg_class]
      end

      def create_message(*args)
        klass = verify_args(*args)
        klass.create_message(*args)
      end

      def recreate_message(*args)
        klass = verify_args(*args)
        klass.recreate_message(*args)
      end

      def register_subclass(klass)
        DripDrop::AutoMessageClass.message_subclasses[klass.to_s] = klass
      end
    end
  end

  #Including this module into your subclass will automatically register the class
  #with AutoMessageClass
  module SubclassedMessage
    def self.included(base)
      DripDrop::AutoMessageClass.register_subclass base
    end
  end
end
