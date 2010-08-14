require '../lib/dripdrop/collector'

puts "Starting..."
DripDrop::Collector.new.run
puts "Ended"
