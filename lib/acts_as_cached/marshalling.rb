module ActsAsCached
  module Marshalling
    def self.included(base)
      if base.ancestors.select { |constant| constant.is_a? Class }.include?(::ActiveRecord::Base)
        base.class_eval <<-"EOM"
          include InstanceMethods
        EOM
        
        ::ActiveRecord::Associations::AssociationProxy.class_eval <<-"EOM"
          include ProxyMethods
        EOM
      end
    end
    
    # Methods for ActiveRecord
    module InstanceMethods
      def marshal_dump
        self.attributes
      end
    
      def marshal_load(attributes)
        self.instance_variable_set("@attributes", attributes)
        self.instance_variable_set("@attributes_cache", Hash.new)

        if self.respond_to_without_attributes?(:after_find)
          self.send(:callback, :after_find)
        end

        if self.respond_to_without_attributes?(:after_initialize)
          self.send(:callback, :after_initialize)
        end

        self
      end
    end    
    
    # Methods for Proxies to dump correctly
    module ProxyMethods
      def marshal_dump
        self.target
      end

      def marshal_load(raw)
        self.target = raw
      end
    end
  end
end