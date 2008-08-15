%w(cached_association_reflection cached_association_proxy has_many_cached_proxy).each { |file| require File.join("acts_as_cached", "cached_associations", file)}

module ActsAsCached
  module CachedAssociations
    def self.included(base)
      if base.ancestors.select { |constant| constant.is_a?(Class) }.include?(::ActiveRecord::Base)
        base.extend ClassMethods
        base.send(:include, InstanceMethods)
      end
    end
    
    module ClassMethods
      # Usage:
      # 
      # class User < ActiveRecord::Base
      #   has_many_cached :cats
      # end
      def has_many_cached(association_id, options = {}, &extensions)
        has_many(association_id, options, &extensions)
        
        reflection = create_has_many_cached_reflection(association_id, options)
        
        define_method("cached_#{association_id}") do
          instance_variable_get("@cached_#{association_id}") || 
            instance_variable_set("@cached_#{association_id}", HasManyCachedProxy.new(self, reflection))
        end
      end
      
      def cached_reflections
        read_inheritable_attribute(:cached_reflections) || write_inheritable_attribute(:cached_reflections, {})
      end
            
      protected
      
      def create_has_many_cached_reflection(name, options)
        reflection = ActsAsCached::CachedAssociationReflection.new(:has_many_cached, name, options, self)
        write_inheritable_hash :cached_reflections, name => reflection
        reflection
      end
    end
   
   module InstanceMethods
     def cached_associations
       @cached_associations ||= {}
     end
     
     def clear_association_cache
       self.cached_associations.clear
       super
     end
   end 
  end
end