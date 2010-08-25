require 'rubygems'
require 'bert'

class DripDrop
  #DripDrop::Message messages are exchanged between all tiers in the architecture
  #A Message is composed of a name, head, and body. The name exists primarily for the
  #purpose of native ZMQ filtering, since ZMQ can filter based on a message prefix.
  #
  #The name is any string consisting of non-null chars.
  #The rest of the payload is a BERT encoded head and body, both of which are hashes.
  #The head and body don't have rigid definitions yet, use as you please.
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
      "#{@name}\0#{BERT.encode({:head => @head, :body => @body})}"
    end
    
    #Convert the Message to a hash like:
    #{:name => @name, :head => @head, :body => @body}
    def to_hash
      {:name => @name, :head => @head, :body => @body}
    end

    #Parses an encoded message
    def self.parse(msg)
      return nil if msg.nil? || msg.empty?
      #This makes parsing ZMQ messages less painful, even if its ugly here
      #We check the class name as a string if case we don't have ZMQ loaded
      if msg.class.to_s == 'ZMQ::Message'
        msg = msg.copy_out_string 
        return nil if msg.empty?
      end
      name, encoded_body = msg.split("\0",2)
      decoded = BERT.decode(encoded_body)
      self.new(name, :head => decoded[:head], :body => decoded[:body])
    end
  end
end
