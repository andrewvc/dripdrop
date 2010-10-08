require 'spec_helper'

describe "zmq xreq/xrep" do
  def xr_tranceive_messages(to_send,&block)
    responses = []
    
    @ddn = DripDrop::Node.new do
      addr = rand_addr
      
      rep = zmq_xrep(addr, :bind)
      req = zmq_xreq(addr,:connect)
      
      rep.on_recv do |identifier,seq,message|
        yield(identifier,seq,message) if block
        responses << {:identifier => identifier, :seq => seq, :message => message}
      end
       
      to_send.each {|message| req.send_message(message)}
    end
    
    @ddn.start
    sleep 0.1
    @ddn.stop
    
    responses
  end
  describe "basic sending and receiving" do
    before do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      @responses = xr_tranceive_messages(@sent)
    end

    it "should receive all sent messages in order" do
      @sent.zip(@responses).each do |sent,response|
        sent.name.should == response[:message].name
      end
    end
  end
end
