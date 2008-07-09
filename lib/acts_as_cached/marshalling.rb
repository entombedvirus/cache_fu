module ActsAsCached
  module MarshallingMethods
    def self.included(base)
      puts "HAI"
      if base.is_a?(::ActiveRecord::Base)
        base.class_eval <<-EOM
          def marshal_dump
            self.attributes
          end
        
          def marshal_load(raw)
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
        EOM
      end
    end
  end
end