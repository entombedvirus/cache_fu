module ActsAsCached
  module CachedAssociations
    class CachedAssociationReflection < ActiveRecord::Reflection::AssociationReflection
      def derive_class_name
        # get the class_name of the belongs_to association of the through reflection
        if through_reflection
          options[:source_type] || source_reflection.class_name
        else
          class_name = name.to_s.camelize
          class_name = class_name.singularize if [ :has_many_cached ].include?(macro)
          class_name
        end
      end
    end
  end
end
