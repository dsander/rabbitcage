# RabbitCage

**WARNING: This project is at a very early stage of development. The command line options and the config file format will most likely change in future versions.**

RabbitCage is a AMQP application firewall build on EventMachine. The code has been heavily inspired by mojombo's awesome [ProxyMachine](http://github.com/mojombo/proxymachine/).

RabbitCage was written because RabbitMQ's access control capabilities are rather limited.

RabbitCage works as a transparent, content aware proxy between the connecting client and a AMQP broker (currently only tested with RabbitMQ). Based on configured ACL-like rules RabbitCage will either forward or reject the message. Messages sent from the broker are forwarded directly to the client using EventMachine's [proxy incoming to](http://eventmachine.rubyforge.org/EventMachine/Connection.html#M000275), though it will just affect the client -> server performance.

## Installation

	sudo gem install rabbitcage

## Running

	Usage:
	rabbitcage -c <config file> [-h <host>] [-p <port>]
	
	Options:
	    -c, --config CONFIG              Configuration file
	    -h, --host HOST                  Hostname to bind. Default 0.0.0.0
	    -p, --port PORT                  Port to listen on. Default 5672
	    -r, --remote-host HOST           Hostname of the RabbitMQ server to connect to. Default 'localhost'
	    -x, --remote-port PORT           Port of the RabbitMQ server to connect to. Default 5673
	    -v                               Verbose output (denied requests).
	    -V                               Very verbose output (denied requests/allowed requests).
	    -D                               Debug output (denied requests/allowed requests/debug info).

## Example config file
	# Basic syntax:
	# allow|deny 'username'|:all, AMQP method|:all, AMQP class|:all, Hash of AMQP method properties
	#
	# This example will allow the admin user to perform any action on the broker.
	# A guest is allowed to consume every exchange which name does not start with 'private_' and
	# register every queue which name does not start with 'reserved_'
	include RabbitCageACL
	config do
	  allow 'admin', :all, :all
	  allow 'guest', :all, :queue, :name => /^(?!reserved_)/
	  allow 'guest', :all, :exchange, :name => /^(?!private_)/
	  allow 'guest', [:consume, :get], :basic
	  allow 'guest', :all, :connection
	  allow 'guest', :all, :channel
	  allow 'guest', :all, :access
	  default :deny
	end

## Performance
Here are some basic performance measurements which compares a raw connection to RabbitMQ with a filtered one. Check the [spec/performance/test.rb](http://github.com/dsander/rabbitcage/blob/master/spec/performance/test.rb) script to get information about how the tests were run. If you have a more benchmark results or suggestions about how to change the benchmark, please let me know.

	Average message delay:
	RabbitMQ    : 0.00293165922164917
	RabbitCache : 0.00457870006561279

	For a 1kb message do 1000 times:
	RabbitMQ    push to queue : 0.443398952484131
	RabbitMQ    pop from queue: 0.711700439453125
	RabbitMQ    async get     : 0.847184419631958
	RabbitCache push to queue : 0.764634847640991
	RabbitCache pop from queue: 1.02018523216248
	RabbitCache async get     : 0.852582693099976


## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2009 Dominik Sander. See LICENSE for details.
