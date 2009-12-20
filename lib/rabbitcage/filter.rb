# encoding: utf-8

module RabbitCageACL
  def allow user, action, object, properties = {}
    RabbitCage::Filter.register :allow, user, action, object, properties 
  end
  def deny user, action, object, properties = {}
    RabbitCage::Filter.register :deny, user, action, object, properties 
  end
  
  def default action
    RabbitCage::Filter.set_default(action)
  end
end

class RabbitCage
  class Filter
    @rules = {}
    
    def self.register permission, user, action, object, properties
      available_actions = {:queue => ['Declare', 'Bind', 'Unbind', 'Delete', 'Purge'],
                           :connection => ['Start', 'StartOk', 'Open', 'Tune', 'TuneOk', 'Close', 'Redirect', 'Secure'],
                           :channel => ['Open', 'Flow', 'Alert', 'Close', 'CloseOk'],
                           :exchange => ['Declare', 'Delete'],
                           :access => ['Request'],
                           :basic => ['Qos', 'Consume', 'Cancel', 'Publish', 'Deliver', 'Get', 'Ack', 'Reject']
                         }
      klass = []
      if action.is_a? Array
        klass = action.collect { |a| "AMQP::Protocol::#{object.camelize}::#{a.camelize}" }.join(',')
      else
        if action == :all && object != :all
          klass = available_actions[object].collect { |x| "AMQP::Protocol::#{object.camelize}::#{x}" }
        elsif action == :all && object == :all
          klass = :any
        elsif action != :all && object == :all
          raise "This acl format is currently not supported"
          exit
        else
          klass = "AMQP::Protocol::#{object.camelize}::#{action.camelize}"
        end
      end
      klass = klass.join(', ') if klass.class == Array
      @rules[klass] = [] unless @rules[klass].class == Array
      
      name = properties.delete(:name)
      properties[object] = name if name
      cond = []
      cond << ('@user =' << (user.is_a?(Regexp) ? "~ #{user.inspect}" : "= '#{user}'"))  if user != :all
        
      properties.each_pair do |p, value|
        cond << ("frame.#{p} =" << (value.is_a?(Regexp) ? "~ #{value.inspect}" : "= '#{value}'"))
      end
      
      @rules[klass] << {:permission => permission, :user => user, :properties => cond.join(' and ') }
    end
    
    def self.generate_properties(properties, object)
      properties
    end
    
    def self.set_default action
      @default = action
    end 
    
    def self.build
      require 'erb'
      method = ERB.new(%q[
  def filter(frame)
    <%- if @rules.any? -%>
      <%- @rules[:any].each do |rule| -%>
        return :<%= rule[:permission]  %> if <%= rule[:properties] %>
      <%- end -%>
      case frame  # 4
        <%- @rules.each_pair do |klass, r|-%>
          <%-  next if klass == :any -%>
          when <%= klass %>
            <%- r.each do |rule| -%>
              return :<%= rule[:permission]  %> if <%= rule[:properties] %>
            <%- end -%>
        <%- end -%>
      end
    <%- end -%>
    :<%= @default %>
  end
  ].gsub!(/^  /,''), nil, '>-%').result(binding)  
    LOGGER.debug "Generated filter method:\n#{method}"
    RabbitCage::ClientConnection.class_eval method
  
    end
  end
end