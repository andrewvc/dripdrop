require 'rubygems'
require 'bert'

class DripDrop
  class Message
    attr_accessor :name, :body
    
    def initialize(name,body)
      raise "No null chars allowed in message names!" if name.include?("\0")
      @name = name
      @body  = body
    end
    
    def encoded
      "#{@name}\0#{BERT.encode(@body)}"
    end
    
    def self.parse(msg)
      name, encoded_body = msg.split("\0",2)
      self.new(name, BERT.decode(encoded_body))
    end
  end
end
