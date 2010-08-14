require 'rubygems'
require 'bert'

class DripDrop
  class Message
    attr_accessor :name, :head, :body
    
    def initialize(name,extra={})
      raise "No null chars allowed in message names!" if name.include?("\0")
       
      @head = extra[:head] || {}
      raise "Message head must be a hash!" unless @head.is_a?(Hash)
      
      @name = name
      @body = extra[:body]
    end
    
    def encoded
      "#{@name}\0#{BERT.encode({:head => @head, :body => @body})}"
    end
    
    def to_hash
      {:name => @name, :head => @head, :body => @body}
    end

    def self.parse(msg)
      name, encoded_body = msg.split("\0",2)
      decoded = BERT.decode(encoded_body)
      self.new(name, :head => decoded[:head], :body => decoded[:body])
    end
  end
end
