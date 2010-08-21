# dripdrop

0MQ Based App Event Monitoring / processing.
A work in progress.

# Why use dripdrop?

dripdrop does this well for a few reasons.

* It's fast. dripdrop doesn't slow down your app. 0MQ + Bert are fast. Sending a message does not block.
* It's flexible. By leveraging 0MQ pub/sub sockets you can do some amazing things simply.
* It's easy.

# Check out examples/rack-stats . Try running the core.rb and webserver examples.
You can monitor web traffic over Rack in realtime at localhost:3000/ws

## Copyright

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
