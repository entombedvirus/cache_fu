module ActsAsCached
  module CachedAssociations
    class CachedAssociationReflection < ActiveRecord::Reflection::AssociationReflection
      def default_reflection
        @default_reflection ||= self.active_record.reflections[self.name]
      end
      
      def derive_class_name
        # get the class_name of the belongs_to association of the through reflection
        if through_reflection
          options[:source_type] || source_reflection.class_name
        else
          class_name = name.to_s.camelize
          class_name = class_name.singularize if [ :has_many_cached :has_paginated_list ].include?(macro)
          class_name
        end
      end
      
      def derive_primary_key_name
        if macro == :belongs_to_cached
          "#{name}_id"
        elsif options[:as]
          "#{options[:as]}_id"
        else
          active_record.name.foreign_key
        end
      end
    end
  end
end
