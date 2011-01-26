require 'rubygems'
require 'sinatra'
require 'dripdrop/message'

post '/endpoint' do
  puts DripDrop::Message.decode_json(request.body.read).inspect
  DripDrop::Message.new('ack').json_encoded
end
