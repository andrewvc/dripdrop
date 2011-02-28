require 'spec_helper'
require 'set'

describe "zmq push/pull" do
  def pp_send_messages(to_send)
    responses = []
    push = nil
    pull = nil
    
    @node = run_reactor(2) do
      addr = rand_addr
      
      push = zmq_push(addr, :bind)
      
      pull1 = zmq_pull(addr, :connect)
      pull2 = zmq_pull(addr, :connect)
      pull = [pull1, pull2] 
      
      pull1.on_recv do |message|
        message.head['recv_sock'] = 1
        responses << message
      end
       pull2.on_recv do |message|
        message.head['recv_sock'] = 2
        responses << message
      end
       
      sleep 1

      to_send.each {|message| push.send_message(message)}
    end
     
    {:responses => responses, :handlers => { :push => push, :pull => [pull] }}
  end
  describe "basic sending and receiving" do
    before(:all) do
      @sent = []
      10.times {|i| @sent << DripDrop::Message.new("test-#{i}")}
      pp_info = pp_send_messages(@sent)
      @responses     = pp_info[:responses]
      @push_handler  = pp_info[:handlers][:push]
      @pull_handlers = pp_info[:handlers][:pull]
    end

    it "should receive all sent messages" do
      resp_names = @responses.map(&:name).inject(Set.new) {|memo,rn| memo << rn}
      @sent.map(&:name).each {|sn| resp_names.should include(sn)}
    end
    
    it "should receive messages on both pull sockets" do
      @responses.map {|r| r.head['recv_sock']}.uniq.sort.should == [1,2]
    end
  end
end
