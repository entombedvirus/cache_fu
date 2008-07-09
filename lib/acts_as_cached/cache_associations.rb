module ActsAsCached
  module ClassMethods
    def belongs_to_cached(association_id, options = {})
      self.belongs_to(association_id, options)
      reflection = self.reflections[association_id]
      
      define_method("cached_#{reflection.name}") do |*params|
        reload_from_cache = params.first
        association = instance_variable_get("@cached_#{reflection.name}")
        
        if association.nil? || reload_from_cache
          association = reflection.klass.get_cache(self.send(reflection.primary_key_name))
          instance_variable_set("@cached_#{reflection.name}", association)
        end        
        
        association
      end
    end

    def has_one_cached(association_id, options = {})
      self.has_one(association_id, options)
      reflection = self.reflections[association_id]
      ids_reflection = "#{reflection.name}_id"
      
      define_method("cached_#{ids_reflection}") do |*params|
        force_reload = params.first unless params.empty?
        cached_association_id = self.class.cache_store(:get, "#{self.cache_key}:#{ids_reflection}")
        if cached_association_id.nil? || force_reload
          begin
            cached_association_id = send(ids_reflection)
          rescue ActiveRecord::RecordNotFound
            cached_association_id = nil
          end

          return nil  if cached_association_id.nil?
          self.class.cache_store(:set, "#{self.cache_key}:#{ids_reflection}", cached_association_id)
        end

        cached_association_id
      end
      
      define_method("cached_#{ids_reflection}=") do |cached_association_id|
        self.class.cache_store(:set, "#{self.cache_key}:#{ids_reflection}", cached_association_id)
        instance_variable_set("@cached_#{reflection.name}", nil)
      end
      
      define_method("cached_#{reflection.name}") do |*params|
        reload_from_cache = params.first
        association = instance_variable_get("@cached_#{reflection.name}")
        
        if association.nil? || reload_from_cache
          association = send("cached_#{ids_reflection}", *params)
          association = reflection.klass.get_cache(association) if association
          instance_variable_set("@cached_#{reflection.name}", association)
        end
        
        association
      end
      
      add_has_one_klass_callbacks!(reflection, ids_reflection)
    end

    def has_many_cached(association_id, options = {})
      self.has_many(association_id, options)
      reflection = self.reflections[association_id]
      singular_reflection = reflection.name.to_s.downcase.singularize
      ids_reflection = "#{singular_reflection}_ids"
      
      define_method("cached_#{ids_reflection}") do |*params|
        force_reload = params.first unless params.empty?
        cached_association = self.class.cache_store(:get, "#{self.cache_key}:#{ids_reflection}")
        if cached_association.nil? || force_reload
          begin
            ids_msg = self.respond_to?("#{ids_reflection}_for_cache".to_sym) ? "#{ids_reflection}_for_cache" : ids_reflection
            cached_association =  send(ids_msg.to_sym)
          rescue ActiveRecord::RecordNotFound
            cached_association = nil
          end

          return nil  if cached_association.nil?
          self.class.cache_store(:set, "#{self.cache_key}:#{ids_reflection}", cached_association)
        end

        cached_association
      end
      
      define_method("cached_#{ids_reflection}=") do |cached_association_id|
        self.class.cache_store(:set, "#{self.cache_key}:#{ids_reflection}", cached_association_id)
        instance_variable_set("@cached_#{reflection.name}", nil)
      end
      
      define_method("cached_#{reflection.name}") do |*params|
        reload_from_cache = params.first
        association = instance_variable_get("@cached_#{reflection.name}")
        
        if association.nil? || reload_from_cache
          cached_association_ids = send("cached_#{ids_reflection}", *params)
          cached_association_ids.compact!
          
          # Possible GOTCHA: Hash#values does not preserve order. Hence, the associated objects
          # returned by the next line might be in a different order than their respective
          # ids in cached_association_ids
          
          if (cached_association_ids && cached_association_ids.size > 0)
            assoc_objs = reflection.klass.get_caches(cached_association_ids)
            association = assoc_objs.is_a?(Hash) ? assoc_objs.values : assoc_objs
            association = Array(association).flatten.compact
          else
            association = []
          end
          
          instance_variable_set("@cached_#{reflection.name}", association)
        end
        
        association
      end
      
      add_has_many_klass_callbacks!(reflection, ids_reflection)
    end
  
    protected
    
    def add_has_one_klass_callbacks!(reflection, ids_reflection)
      pkey_name = reflection.primary_key_name
      skey_name = :id
      
      reflection.klass.after_save do |instance|
        if instance.changes[pkey_name]
          # Need to add id to parent's cache list ONLY if parent had the id list in cache in the first place
          key = "#{instance.send(pkey_name)}:#{ids_reflection}"
          if reflection.active_record.cached?(key)
            reflection.active_record.set_cache(key, instance.send(skey_name))
          end
          
          # if we are doing an update of the foreign_key rather than an insert, make sure we remove the old parent's cache
          key = "#{instance.changes[pkey_name].first}:#{ids_reflection}"
          unless instance.changes[pkey_name].first.nil? || !reflection.active_record.cached?(key)
            reflection.active_record.cache_store(:delete, reflection.active_record.cache_key(key))
          end
        end
      end
      
      reflection.klass.after_destroy do |instance|
        key = "#{instance.send(pkey_name)}:#{ids_reflection}"
        if reflection.active_record.cached?(key)
          reflection.active_record.cache_store(:delete, reflection.active_record.cache_key(key))
        end
      end
    end
    
    def add_has_many_klass_callbacks!(reflection, ids_reflection)
      pkey_name = reflection.options[:through] ? reflection.through_reflection.primary_key_name : reflection.primary_key_name
      skey_name = reflection.options[:through] ? reflection.source_reflection.primary_key_name : :id
      r = reflection.options[:through] ? reflection.through_reflection : reflection
      
      r.klass.after_save do |instance|
        # if the foreign_key on self was changed
        if instance.changes[pkey_name]

          # Need to add id to parent's cache list ONLY if parent had the id list in cache in the first place
          key = "#{instance.send(pkey_name)}:#{ids_reflection}"
          unless (assoc_ids = reflection.active_record.fetch_cache(key)).nil?
            assoc_ids << instance.send(skey_name)
            reflection.active_record.set_cache(key, assoc_ids.uniq)
          end
          
          # if we are doing an update of the foreign_key rather than an insert, make sure we remove ourselves from our old parent's cache
          key = "#{instance.changes[pkey_name].first}:#{ids_reflection}"
          unless instance.changes[pkey_name].first.nil? || (assoc_ids = reflection.active_record.fetch_cache(key)).nil?
            assoc_ids.delete(instance.send(skey_name))          
            reflection.active_record.set_cache(key, assoc_ids.uniq)
          end
        end
      end
      
      # If an obj is destroyed, update the parent's cached id list
      r.klass.after_destroy do |instance|
        key = "#{instance.send(pkey_name)}:#{ids_reflection}"
        unless (assoc_ids = reflection.active_record.fetch_cache(key)).nil?
          assoc_ids.delete(instance.send(skey_name))
          reflection.active_record.set_cache(key, assoc_ids.uniq)
        end
      end
    end
    
  end
end
