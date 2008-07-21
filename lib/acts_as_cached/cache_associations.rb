module ActsAsCached
  module CacheAssociations
    def self.included(base)
      if base.ancestors.select {|constant| constant.is_a?(Class)}.include?(::ActiveRecord::Base)
        base.extend ClassMethods
      end
    end
    module ClassMethods
      def self.extended(base)
        base.class_eval <<-END_EVAL
          def cached_associations
            @cached_associations ||= {}
          end
          
          def clear_association_cache
            self.cached_associations.clear
            super
          end
        END_EVAL
      end

      def belongs_to_cached(association_id, options = {})
        self.belongs_to(association_id, options)
        reflection = self.reflections[association_id]

        define_method("cached_#{reflection.name}") do |*params|
          reload_from_cache = params.first
          association = self.cached_associations[reflection.name]
          
          if association.nil? || reload_from_cache
            association = reflection.klass.get_cache(self.send(reflection.primary_key_name))
            self.cached_associations[reflection.name] = association
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
          self.cached_associations.delete(reflection.name)
        end

        define_method("cached_#{reflection.name}") do |*params|
          reload_from_cache = params.first
          association = self.cached_associations[reflection.name]

          if association.nil? || reload_from_cache
            association = send("cached_#{ids_reflection}", *params)
            association = reflection.klass.get_cache(association) if association
            self.cached_associations[reflection.name] = association if association
          end

          association
        end

        add_has_one_klass_callbacks!(reflection, ids_reflection)
      end

      def has_many_cached(association_id, options = {})
        raise ":order and :limit are not allowed as valid options for a has_many_cached association." if options[:order] || options[:limit]
        
        add_has_many_association_callbacks!(options)
        
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
          self.cached_associations.delete(reflection.name)
        end

        define_method("cached_#{reflection.name}") do |*params|
          reload_from_cache = params.first
          
          # Try the instance cache first
          associates = self.cached_associations[reflection.name]
          associate_ids = nil
          
          # If that is a miss, try the cache store next
          if associates.blank? || reload_from_cache
            associate_ids = self.class.cache_store(:get, "#{self.cache_key}:#{ids_reflection}")
            
            if associate_ids
              cached_values = reflection.klass.get_caches(associate_ids)
              associates = associate_ids.inject([]) {|mem, val| mem << cached_values[val]}
            end
          end
          
          # And finally we consult the database if all else fails
          if associates.blank?
            associates = send(reflection.name, *params).to_a
            associate_ids = associates.map(&:id)

            unless associates.blank?
              associates.each {|obj| obj.set_cache}
            else
              associates = []
            end

            self.cached_associations[reflection.name] = associates if associates
            self.class.cache_store(:set, "#{self.cache_key}:#{ids_reflection}", associate_ids) if associate_ids
          end

          associates
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
        # debugger if reflection.options[:through]
        pkey_name = reflection.options[:through] ? reflection.through_reflection.primary_key_name : reflection.primary_key_name
        skey_name = (reflection.options[:through] && reflection.source_reflection) ? reflection.source_reflection.primary_key_name : :id
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
      
      def add_has_many_association_callbacks!(options)
        options[:after_add] ||= []
        options[:after_add] = Array(options[:after_add])
        options[:after_add] << proc { |owner, associate|
          owner.cached_associations.clear
        }
        
        options[:after_remove] ||= []
        options[:after_remove] = Array(options[:after_remove])
        options[:after_remove] << proc { |owner, associate|
          owner.cached_associations.clear
        }
      end
    end
    
    
  end
end
