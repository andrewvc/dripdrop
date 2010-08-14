# dripdrop

0MQ Based App Event Monitoring / processing 

## An example with a WebSocket UI:

To run a simple example, feeding data to a websockets UI
#### Aggregate agents with zmq_forwarder (comes with zmq)
    $ zmq_forwarder examples/forwarder.cfg

#### Start up the drip drop publisher example
    $ drip-publisher

#### Assuming you have mongodb running
    $ drip-mlogger
  
#### Start up a webserver to host the HTML/JS for a sample websocket client
    $ cd DRIPDROPFOLDER/example/web/
    $ ruby server

## Example Topology

![topology](http://github.com/andrewvc/dripdrop/raw/master/doc/doc_img/topology.png "Topology")

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
