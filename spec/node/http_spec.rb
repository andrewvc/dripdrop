require 'spec_helper'

describe "http" do
  def http_send_messages(to_send,&block)
    responses = []
    client = nil
    server = nil
    
    @ddn = DripDrop::Node.new do
      addr = rand_addr
      
      zmq_subscribe(rand_addr, :bind) do |message|
      end
      
      client = http_client(addr)
      
      server = http_server(addr).on_recv do |message,response|
        $stdout.flush
        responses << message
        response.send_message(message)
      end
      
      to_send.each do |message|
        EM::next_tick do
          http_client(addr).send_message(message) do |resp_message|
            block.call(message,resp_message)
          end
        end
      end
    end
    
    @ddn.start
    sleep 0.1
    @ddn.stop
    
    {:responses => responses, :handlers => {:server => [server] }}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      @client_responses = []
      http_info = http_send_messages(@sent) do |sent_message,resp_message|
        @client_responses << {:sent_message  => sent_message,
                              :resp_message  => resp_message}
      end
      @responses     = http_info[:responses]
      @push_handler  = http_info[:handlers][:push]
      @pull_handlers = http_info[:handlers][:pull]
    end

    it "should receive all sent messages" do
      resp_names = @responses.map(&:name).inject(Set.new) {|memo,rn| memo << rn}
      @sent.map(&:name).each {|sn| resp_names.should include(sn)}
    end
    
    it "should return to the client as many responses as sent messages" do
      @client_responses.length.should == @sent.length
    end
    
    it "should return to the client an identical message to that which was sent" do
      @client_responses.each do |resp|
        resp[:sent_message].name.should == resp[:resp_message].name
      end
    end
  end
end
