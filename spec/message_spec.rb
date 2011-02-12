require 'spec_helper'

class SpecMessageClass < DripDrop::Message
  include DripDrop::SubclassedMessage
end

describe DripDrop::Message do
  describe "basic message" do
    def create_basic
      attrs = {
        :name => 'test',
        :head => {'foo' => 'bar'},
        :body => ['foo', 'bar', 'baz']
      }
      message = DripDrop::Message.new(attrs[:name],:head => attrs[:head],
                                                   :body => attrs[:body])
      [message, attrs]
    end
    it "should create a basic message without raising an exception" do
      lambda {
        message, attrs = create_basic
      }.should_not raise_exception
    end
    describe "with minimal attributes" do
      it "should create a message with only a name" do
        lambda {
          DripDrop::Message.new('nameonly')
        }.should_not raise_exception
      end
      it "should set the head to a single key hash containing message class if nil provided" do
        DripDrop::Message.new('nilhead', :head => nil).head.should == {'message_class' => 'DripDrop::Message'}
      end
      it "should raise an exception if a non-hash, non-nil head is provided" do
        lambda {
          DripDrop::Message.new('arrhead', :head => [])
        }.should raise_exception(ArgumentError)
      end
    end
    describe "encoding" do
      before(:all) do
        @message, @attrs = create_basic
      end
      it "should encode to valid JSON hash without error" do
        enc = @message.encoded
        enc.should be_a(String)
        Yajl::Parser.parse(enc).should be_a(Hash)
      end
      it "should decode encoded messages without errors" do
        DripDrop::Message.decode(@message.encoded).should be_a(DripDrop::Message)
      end
      it "should decode JSON encoded messages without errors" do
        DripDrop::Message.decode_json(@message.json_encoded).should be_a(DripDrop::Message)
      end
      it "should convert messages to Hash representations" do
        @message.to_hash.should be_a(Hash)
      end
      it "should be able to turn hash representations back into Message objs" do
        DripDrop::Message.from_hash(@message.to_hash).should be_a(DripDrop::Message)
      end
    end
    describe "subclassing" do
      def create_auto_message
        attrs = {
          :name => 'test',
          :head => {'foo' => 'bar', 'message_class' => 'SpecMessageClass'},
          :body => ['foo', 'bar', 'baz']
        }

        message = DripDrop::AutoMessageClass.create_message(attrs)

        [message, attrs]
      end
      before(:all) do
        @message, @attrs = create_auto_message
      end
      it "should be added to the subclass message class hash if SubclassedMessage included" do
        DripDrop::AutoMessageClass.message_subclasses.should include('SpecMessageClass' => SpecMessageClass)
      end
      it "should throw an exception if we try to recreate a message of the wrong class" do
        msg = DripDrop::Message.new('test')
        lambda{SpecMessageClass.recreate_message(msg.to_hash)}.should raise_exception
      end

      describe "DripDrop::AutoMessageClass" do
        it "should create a properly classed message based on head['message_class']" do
          @message.should be_a(SpecMessageClass)
        end
        it "should recreate a message based on head['message_class']" do
          DripDrop::AutoMessageClass.recreate_message(@message.to_hash).should be_a(SpecMessageClass)
        end
      end
    end
  end
end
