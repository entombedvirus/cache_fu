module ActsAsCached
  module CachedAssociations
    class HasManyCachedReflection < CachedAssociationReflection
      
      def initialize(*args)
        super
        add_association_methods!
        add_klass_callbacks!
      end

      def association_ids_msg
        @association_ids_msg ||= "#{self.name.to_s.downcase.singularize}_ids"
      end
      
      private
      
      def add_association_methods!
        reflection = self

        self.active_record.class_eval do
          # Remember the context switches here. If you have User.has_many :cats
          # At this point, self refers to User
          define_method("cached_#{reflection.name}") do |*params|
            # And here self refers to some user object
            return self.send(reflection.name) if self.new_record?
            
            force_load_from_cache = params.first
            returning(instance_variable_get("@cached_#{reflection.name}") || instance_variable_set("@cached_#{reflection.name}", HasManyCachedProxy.new(self, reflection))) do |proxy|
              proxy.reload if force_load_from_cache
            end
          end
          
          define_method("cached_#{reflection.association_ids_msg}") do |*params|
            return self.send(reflection.association_ids_msg) if self.new_record?
            
            force_reload = params.first unless params.empty?
            proxy = send("cached_#{reflection.name}", force_reload)
            cached_association = self.class.cache_store(:get, proxy.cache_key)

            if cached_association.nil? || force_reload
              begin
                cached_association =  send(reflection.association_ids_msg.to_sym)
              rescue ActiveRecord::RecordNotFound
                cached_association = nil
              end

              return nil  if cached_association.nil?
              self.class.cache_store(:set, proxy.cache_key, cached_association)
            end

            cached_association
          end
          
          define_method("cached_#{reflection.association_ids_msg}=") do |association_ids|
            proxy = send("cached_#{reflection.name}")
            self.class.cache_store(:set, proxy.cache_key, association_ids)
            proxy.reset
          end
        end
      end      
      
      def add_klass_callbacks!
        pkey_name = (self.options[:through] ? self.through_reflection.primary_key_name : self.primary_key_name).to_s
        skey_name = (self.options[:through] && self.source_reflection) ? self.source_self.primary_key_name : :id
        r = self.options[:through] ? self.through_reflection : self

        
        r.klass.after_save do |instance|
          # if the foreign_key on self was changed
          if instance.changes[pkey_name]

            # Need to add id to parent's cache list ONLY if parent had the id list in cache in the first place
            key = "#{instance.send(pkey_name)}:#{self.name}"
            unless (assoc_ids = self.active_record.fetch_cache(key)).nil?
              assoc_ids << instance.send(skey_name)
              self.active_record.set_cache(key, assoc_ids.uniq)
            end

            # if we are doing an update of the foreign_key rather than an insert, make sure we remove ourselves from our old parent's cache
            key = "#{instance.changes[pkey_name].first}:#{self.name}"
            unless instance.changes[pkey_name].first.nil? || (assoc_ids = self.active_record.fetch_cache(key)).nil?
              assoc_ids.delete(instance.send(skey_name))          
              self.active_record.set_cache(key, assoc_ids.uniq)
            end
          end
        end

        # If an obj is destroyed, update the parent's cached id list
        r.klass.after_destroy do |instance|
          key = "#{instance.send(pkey_name)}:#{self.name}"
          unless (assoc_ids = self.active_record.fetch_cache(key)).nil?
            assoc_ids.delete(instance.send(skey_name))
            self.active_record.set_cache(key, assoc_ids.uniq)
          end
        end
      end      
      
    end
  end
end