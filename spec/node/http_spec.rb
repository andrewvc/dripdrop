require 'spec_helper'

require 'set'

describe "http" do
  
  def http_send_messages(to_send,addr=rand_addr('http'),&block)
    responses = []
    client = nil
    server = nil
    
    @node = run_reactor(2) do
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
    
   {:responses => responses, :handlers => {:server => [server] }}
  end
  
  shared_examples_for "all http nodes" do
    describe "basic sending and receiving" do
      before(:all) do
        @sent = []
        10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
        @client_responses = []
        @http_info = http_send_messages(@sent,@http_test_addr) do |sent_message,resp_message|
          @client_responses << {:sent_message  => sent_message,
                                :resp_message  => resp_message}
        end
        @responses     = @http_info[:responses]
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
  
  describe "http apps using the URL root (/)" do
    before(:all) { @http_test_addr = rand_addr('http') }
    it_should_behave_like "all http nodes"
  end
  
  describe "http apps using a subdirectory of the URL (/subdir)" do
    before(:all) { @http_test_addr = rand_addr('http') + '/subdir' }
    it_should_behave_like "all http nodes"
  end
end
