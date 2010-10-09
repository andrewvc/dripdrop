require 'spec_helper'

describe "zmq xreq/xrep" do
  def xr_tranceive_messages(to_send,&block)
    responses = []
    req = nil
    rep = nil
    
    @ddn = DripDrop::Node.new do
      addr = rand_addr
      
      rep = zmq_xrep(addr, :bind)
      req = zmq_xreq(addr, :connect)
      
      rep.on_recv do |identities,seq,message|
        yield(identities,seq,message) if block
        responses << {:identities => identities, :seq => seq, :message => message}
      end
       
      to_send.each {|message| req.send_message(message)}
    end
    
    @ddn.start
    sleep 0.1
    @ddn.stop
    
    {:responses => responses, :handlers => {:req => req, :rep => rep}}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      xr_info = xr_tranceive_messages(@sent)
      @responses = xr_info[:responses]
      @req_handler  = xr_info[:handlers][:req]
      @rep_handler  = xr_info[:handlers][:rep]
    end

    it "should receive all sent messages in order" do
      @sent.zip(@responses).each do |sent,response|
        sent.name.should == response[:message].name
      end
    end

    it "should have a monotonically incrementing seq for responses" do
      last_seq = 0
      @responses.each do |resp|
        resp[:seq].should == last_seq + 1
        last_seq = resp[:seq]
      end
    end
    
    it "should include the identity of the sending socket" do
      @responses.each {|resp| resp[:identities].should_not be_nil}
    end
    
    it "should send responses back to the proper xreq sender" do
      received_count = 0
      
      ddn = DripDrop::Node.new do
        addr = rand_addr
        
        rep  = zmq_xrep(addr, :bind)
        req1 = zmq_xreq(addr, :connect)
        req2 = zmq_xreq(addr, :connect)
        
        rep.on_recv do |identities,seq,message|
          rep.send_message(identities,seq,message)
        end
         
        r1_msg = DripDrop::Message.new("REQ1 Message")
        r2_msg = DripDrop::Message.new("REQ2 Message")
        
        10.times do
        req1.send_message(r1_msg) do |message|
          received_count += 1
          message.name.should == r1_msg.name
        end
        req2.send_message(r2_msg) do |message|
          received_count += 1
          message.name.should == r2_msg.name
        end
        end
      end
      ddn.start 
      sleep 0.2
      ddn.stop rescue nil #This should work...
      
      received_count.should == 20
    end
  end
end
