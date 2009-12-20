require 'rubygems'
require 'eventmachine'
require 'amqp'
require 'logger'
require 'socket'

require 'rabbitcage/client_connection'
require 'rabbitcage/server_connection'
require 'rabbitcage/filter'
require 'rabbitcage/core_extensions'
LOGGER = Logger.new(STDOUT)
LOGGER.datetime_format = "%m-%d %H:%M:%S "

class RabbitCage
  MAX_FAST_SHUTDOWN_SECONDS = 10

  class << self
    def update_procline
      $0 = "rabbitcage #{VERSION} - #{@@name} #{@@listen} - #{self.stats} cur/max/tot conns"
    end
  
    def stats
      "#{@@counter}/#{@@maxcounter}/#{@@totalcounter}"
    end
  
    def count
      @@counter
    end
  
    def incr
      @@totalcounter += 1
      @@counter += 1
      @@maxcounter = @@counter if @@counter > @@maxcounter
      self.update_procline
      @@counter
    end
  
    def decr
      @@counter -= 1
      if $server.nil?
        LOGGER.info "Waiting for #{@@counter} connections to finish."
      end
      self.update_procline
      EM.stop if $server.nil? and @@counter == 0
      @@counter
    end
  
    def set_config(block)
      @@config = block
    end
  
    def config
      @@config
    end
    
    def rabbit_host
      @@remote_host
    end
    
    def rabbit_port
      @@remote_port
    end
    def build_filter
      RabbitCage.config.call
      @@filter = Filter.build
    end
    
    def filter frame
      Filter.filter frame
    end
  
    def graceful_shutdown(signal)
      EM.stop_server($server) if $server
      LOGGER.info "Received #{signal} signal. No longer accepting new connections."
      LOGGER.info "Waiting for #{RabbitCage.count} connections to finish."
      $server = nil
      EM.stop if RabbitCage.count == 0
    end
  
    def fast_shutdown(signal)
      EM.stop_server($server) if $server
      LOGGER.info "Received #{signal} signal. No longer accepting new connections."
      LOGGER.info "Maximum time to wait for connections is #{MAX_FAST_SHUTDOWN_SECONDS} seconds."
      LOGGER.info "Waiting for #{RabbitCage.count} connections to finish."
      $server = nil
      EM.stop if RabbitCage.count == 0
      Thread.new do
        sleep MAX_FAST_SHUTDOWN_SECONDS
        exit!
      end
    end
  
    def run(name, host, port, rhost, rport, log_level)
      @@totalcounter = 0
      @@maxcounter = 0
      @@counter = 0
      @@name = name
      @@listen = "#{host}:#{port}"
      @@remote_host = rhost
      @@remote_port = rport
      LOGGER.level = log_level

      self.update_procline
      EM.epoll
      
      RabbitCage.build_filter
      
      EM.run do
        RabbitCage::ClientConnection.start(host, port)
        trap('QUIT') do
          self.graceful_shutdown('QUIT')
        end
        trap('TERM') do
          self.fast_shutdown('TERM')
        end
        trap('INT') do
          self.fast_shutdown('INT')
        end
      end
    end
  
    def version
      yml = YAML.load(File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION.yml])))
      "#{yml[:major]}.#{yml[:minor]}.#{yml[:patch]}"
    rescue
      'unknown'
    end
  end

  VERSION = self.version
end

module Kernel
  def config(&block)
    RabbitCage.set_config(block)
  end
end