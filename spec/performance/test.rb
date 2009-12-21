require 'amqp'
require 'mq'
require 'eventmachine'
require 'benchmark'
require 'bunny'

# Config file used
#include RabbitCageACL
#require 'pp'
#config do
#  allow 'admin', :all, :all
#  allow 'guest', :all, :queue, :name => /^(?!reserved_)/
#  allow 'guest', :all, :exchange, :name => /^(?!private_)/
#  allow 'guest', [:publish, :consume, :get], :basic
#  allow 'guest', :all, :connection
#  allow 'guest', :all, :channel
#  allow 'guest', :all, :access
#  default :deny
#end


def messure_delay
  delay = []
  i = 0

  amq = MQ.new
    amq.queue('delay', :exclusive=>true, :auto_delete=>true).bind(amq.fanout('performance_test')).subscribe do |msg|
    delay <<  Time.now.to_f-msg.to_f
    if i == 100
      @timer.cancel 
      puts delay.reduce(:+)/delay.length
      AMQP.stop{EM.stop}
    end
  end
  
  @timer = EventMachine::add_periodic_timer(0.01) do
    i += 1
    amq.fanout('performance_test').publish(Time.now.to_f)
  end
end

puts "Average message delay:"
AMQP.start(:port => 5673) do 
  print 'RabbitMQ    : '
  messure_delay
end
AMQP.start(:port => 5672) do 
  print 'RabbitCache : '
  messure_delay
end


def messure_publish_time port, data, message
  b = Bunny.new(:host => 'localhost', :port => port)
  b.start
  
  q = b.queue('performance_test')
   
  res = Benchmark.realtime do
    1000.times do
      q.publish(@data)
    end
  end
  puts "#{message} push to queue : #{res}"
  res = Benchmark.realtime do
    1000.times do
      q.pop
    end
  end
  puts "#{message} pop from queue: #{res}"

  1000.times do
    q.publish(@data)
  end
  b.stop
  i = 1
  
  res = Benchmark.realtime do
    AMQP.start(:port => port) do 
      amq = MQ.new
      amq.queue('performance_test', :exclusive=>true, :auto_delete=>true).bind(amq.fanout('performance_test')).subscribe do |msg|
        i += 1
        if i == 1000
          AMQP.stop{EM.stop}
        end
      end
    end
  end
  puts "#{message} async get     : #{res}"
end

@data = "x"*1024
puts "For a 1kb message do 1000 times:"
messure_publish_time 5673, @data, 'RabbitMQ   '
messure_publish_time 5672, @data, 'RabbitCache'

