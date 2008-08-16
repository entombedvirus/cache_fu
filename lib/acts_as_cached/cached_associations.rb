%w(
  cached_association_reflection 
  cached_association_proxy 
  has_many_cached
  belongs_to_cached
  has_paginated_list
).each { |file| require File.join("acts_as_cached", "cached_associations", file)}

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
      #   class User < ActiveRecord::Base
      #     has_many_cached :cats
      #   end
      def has_many_cached(association_id, options = {}, &extensions)
        raise "Cannot have :limit and :order on has_many_cached associations" if options[:order] || options[:limit]
        
        has_many(association_id, options, &extensions)
        create_has_many_cached_reflection(association_id, options)
      end
      
      # Usage:
      #   class User < ActiveRecord::Base
      #   end
      # 
      #   class Cat < ActiveRecord::Base
      #     belongs_to_cached :user
      #   end
      def belongs_to_cached(association_id, options = {}, &extensions)
        belongs_to(association_id, options, &extensions)
        create_belongs_to_cached_reflection(association_id, options)
      end
      
      # A macro to define a has_many relationship and the accompanying cache machinery specifically to
      # handle an association that is paginated and displayed in reverse chronological order (implemented
      # by ordering using "id DESC").
      # 
      #   class User < ActiveRecord::Base
      #     acts_as_cached
      #     
      #     # Blog posts are displayed automagically ordered by "id DESC", 10 at a time.
      #     has_paginated_list :blog_posts, :limit => 10
      #   end
      def has_paginated_list(association_id, options = {})
        raise ":limit and :order are required options for a has_paginated_list association." unless options[:limit]
        
        association_class = options[:class_name] ? options[:class_name].to_s.constantize : association_id.to_s.classify.constantize        
        has_many(association_id, options.merge({:order => "#{association_class.primary_key} DESC"}))
        create_has_paginated_list_reflection(association_id, options)
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
      
      def create_belongs_to_cached_reflection(name, options)
        reflection = ActsAsCached::CachedAssociations::BelongsToCachedReflection.new(:belongs_to_cached, name, options, self)
        write_inheritable_hash :cached_reflections, name => reflection
        reflection
      end
      
      def create_has_paginated_list_reflection(name, options)
        reflection = ActsAsCached::CachedAssociations::HasPaginatedListReflection.new(:has_paginated_list, name, options, self)
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