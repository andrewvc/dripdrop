require 'rubygems'
require 'bert'
require 'json'

class DripDrop
  #DripDrop::Message messages are exchanged between all tiers in the architecture
  #A Message is composed of a name, head, and body, and should be restricted to types that
  #can be readily encoded to JSON, that means hashes, arrays, strings, integers, and floats
  #internally, they're just stored as BERT
  #
  #The basic message format is built to mimic HTTP. Why? Because I'm a dumb web developer :)
  #The name is kind of like the URL, its what kind of message this is.
  #head should be used for metadata, body for the actual data.
  #These definitions are intentionally loose, because protocols tend to be used loosely.
  class Message
    attr_accessor :name, :head, :body
    
    #Create a new message.
    #example:
    #  Message.new('mymessage', :head => {:timestamp => Time.now}, 
    #    :body => {:mykey => :myval,  :other_key => ['complex']})
    def initialize(name,extra={})
      raise "No null chars allowed in message names!" if name.include?("\0")
       
      @head = extra[:head] || {}
      raise "Message head must be a hash!" unless @head.is_a?(Hash)
      
      @name = name
      @body = extra[:body]
    end
    
    #The encoded message, ready to be sent across the wire via ZMQ
    def encoded
      BERT.encode(self.to_hash)
    end
    
    def encode_json
      self.to_hash.to_json
    end

    #Convert the Message to a hash like:
    #{:name => @name, :head => @head, :body => @body}
    def to_hash
      {:name => @name, :head => @head, :body => @body}
    end

    #Parses an already encoded string
    def self.decode(*args); self.parse(*args) end
    def self.parse(msg)
      return nil if msg.nil? || msg.empty?
      #This makes parsing ZMQ messages less painful, even if its ugly here
      #We check the class name as a string in case we don't have ZMQ loaded
      if msg.class.to_s == 'ZMQ::Message'
        msg = msg.copy_out_string 
        return nil if msg.empty?
      end
      decoded = BERT.decode(msg)
      self.new(decoded[:name], :head => decoded[:head], :body => decoded[:body])
    end

    def self.decode_json(str)
      json_hash = JSON.parse(str)
      self.new(json_hash['name'], :head => json_hash['head'], :body => json_hash['body'])
    end

    private
    
    #Sanitize a string so it'll look good for JSON, BERT, and MongoDB
    def sanitize_structure(structure)
      #TODO: Make this work, and called for head, and body
    end
  end
end
