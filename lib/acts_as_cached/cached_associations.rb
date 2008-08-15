%w(cached_association_reflection cached_association_proxy has_many_cached).each { |file| require File.join("acts_as_cached", "cached_associations", file)}

module ActsAsCached
  module CachedAssociations
    def self.included(base)
      if base.ancestors.select { |constant| constant.is_a?(Class) }.include?(::ActiveRecord::Base)
        base.send(:include, InstanceMethods)
        base.extend ClassMethods
      end
    end
    
    module ClassMethods
      # Usage:
      # 
      # class User < ActiveRecord::Base
      #   has_many_cached :cats
      # end
      def has_many_cached(association_id, options = {}, &extensions)
        raise "Cannot have :limit and :order on has_many_cached associations" if options[:order] || options[:limit]
        
        has_many(association_id, options, &extensions)
        create_has_many_cached_reflection(association_id, options)
      end
      
      def cached_reflections
        read_inheritable_attribute(:cached_reflections) || write_inheritable_attribute(:cached_reflections, {})
      end
            
      protected
      
      def create_has_many_cached_reflection(name, options)
        reflection = ActsAsCached::CachedAssociations::HasManyCachedReflection.new(:has_many_cached, name, options, self)
        write_inheritable_hash :cached_reflections, name => reflection
        reflection
      end      
    end
   
   module InstanceMethods
     def clear_association_cache
       # Clear the association proxy
       self.class.cached_reflections.each {|name, ref| instance_variable_set("@cached_#{name}", nil)}
       
       super
     end
   end 
  end
end