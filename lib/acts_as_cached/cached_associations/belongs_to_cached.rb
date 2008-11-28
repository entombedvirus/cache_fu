module ActsAsCached
  module CachedAssociations
    class BelongsToCachedReflection < CachedAssociationReflection
      def initialize(*args)
        super
        add_association_methods!
      end
      
      private
      
      def add_association_methods!
        reflection = self
        reflection.active_record.class_eval do
          define_method("cached_#{reflection.name}") do |*params|
            return self.send(reflection.name) if self.new_record?
            
            reload_from_cache = params.first
            association = instance_variable_get("@cached_#{reflection.name}")

            if association.nil? || reload_from_cache
              association = \
                begin
                  reflection.klass.get_cache(self.send(reflection.primary_key_name)) 
                rescue ActiveRecord::RecordNotFound => e
                  nil
                end
              instance_variable_set("@cached_#{reflection.name}", association)
            end        

            association
          end          
        end
      end
    end
  end
end