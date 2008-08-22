module ActsAsCached
  module CachedAssociations
    class HasPaginatedListReflection < CachedAssociationReflection
      def initialize(*args)
        super
        add_association_methods!
        add_klass_callbacks!
      end
      
      private
      
      def add_association_methods!
        reflection = self
        reflection.active_record.class_eval do

          define_method "cached_#{reflection.name}" do |*params|
            force_reload = params.first

            associates = instance_variable_get("@cached_#{reflection.name}")

            if force_reload || associates.nil?
              if (associate_ids = self.class.cache_store(:get, "#{self.cache_key}:paginated_list:#{reflection.name}")) 
                associates = reflection.klass.get_caches(associate_ids)
                associates = associates.is_a?(Hash) ? associates.values : associates
                associates = Array(associates).flatten.compact.sort { |a, b| b.send(reflection.klass.primary_key) <=> a.send(reflection.klass.primary_key) } # ORDER BY id DESC
                
              else
                associates = self.send(reflection.name)
                associate_ids = associates.collect(&:id)
                self.class.cache_store(:set, "#{self.cache_key}:paginated_list:#{reflection.name}", associate_ids)
              end
            end

            instance_variable_set("@cached_#{reflection.name}", associates)  if associates

            associates
          end
        end
      end
    
      def add_klass_callbacks!
        pkey_name =  self.options[:through] ? self.through_reflection.primary_key_name : self.primary_key_name
        skey_name =  (self.options[:through] && self.source_reflection) ? self.source_reflection.primary_key_name : :id
        r = self.options[:through] ? self.through_reflection : self
        
        r.klass.after_save do |instance|
          if instance.changes[pkey_name]
            
            key = "#{instance.cache_key}:paginated_list:#{self.name}"
            unless (assoc_ids = self.active_record.fetch_cache(key)).nil?
              assoc_ids.unshift(instance.send(skey_name))
              self.active_record.cache_store(:set, key, assoc_ids[0...r.options[:limit]])
            end
          end
        end
      end
    end
  end
end