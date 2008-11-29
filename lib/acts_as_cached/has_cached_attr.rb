module ActsAsCached
  module HasCachedAttr
    class CachedAttrStore < Hash
      attr_reader :active_record
      
      def initialize(active_record)
        @active_record = active_record
        super()
      end
      
      def [](name)
        unless active_record.loaded_from_cache?
          raise "Attempted to retrieve cached_attr <%s> from <%s> that was not loaded from cache" % [name, active_record]
        end
        
        return super if self.keys.include?(name)
        
        default_value = active_record.class.has_cached_attrs[name]
        returning(default_value.respond_to?(:call) ? default_value.call(active_record) : default_value) do |val|
          self[name] = val
          active_record.write_attribute("cached_attrs", self)
        end
      end
    end
    
    module ClassMethods
      def has_cached_attr(name, default_value)
        include InstanceMethods unless instance_methods.include?("cached_attrs")
        
        class_inheritable_hash :has_cached_attrs, :instance_writer => false
        write_inheritable_hash :has_cached_attrs, name => default_value
      end
    end
    
    module InstanceMethods
      def cached_attrs
        if read_attribute("cached_attrs").nil?
          write_attribute("cached_attrs", CachedAttrStore.new(self)) 
        end
        
        read_attribute("cached_attrs")
      end
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
    end
  end
end