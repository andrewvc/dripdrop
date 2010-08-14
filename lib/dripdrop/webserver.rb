require 'rubygems'
require 'sinatra'

set :static, true
set :logging, false

get '/' do
  puts "Started Sinatra"
  File.open('public/view.html')
end
