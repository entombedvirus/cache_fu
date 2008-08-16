module ActsAsCached
  module CachedAssociations
    class HasManyCachedProxy < CachedAssociationProxy      
      def delete(*records)
        send_to_non_cached_proxy(:delete, *records)

        # Remove them from the cache_store
        associate_ids = records.map(&:id)
        cached_ids = @owner.send("cached_#{@reflection.association_ids_msg}")
        cached_ids.delete(*associate_ids)
        
        @owner.class.cache_store(:set, self.cache_key, cached_ids)
      end
      
      def clear
        @owner.class.cache_store(:delete, self.cache_key)
        send_to_non_cached_proxy(:clear)
      end
      
      def delete_all
        @owner.class.cache_store(:delete, self.cache_key)
        send_to_non_cached_proxy(:delete_all)
      end
      
      def destroy_all
        @owner.class.cache_store(:delete, self.cache_key)
        send_to_non_cached_proxy(:destroy_all)
      end
      
      private

      def load_target
        return true if loaded?

        self.target = if (associate_ids = @owner.class.cache_store(:get, self.cache_key)) # Try the cache_store
          in_cache = @reflection.klass.get_caches(associate_ids)
          associates = associate_ids.inject([]) {|mem, val| mem << in_cache[val]}          
          associates
        else # And then the database
          associates = @owner.send(@reflection.name)
          associate_ids = associates.collect(&:id)
          @owner.class.cache_store(:set, self.cache_key, associate_ids) unless associate_ids.nil?
          associates
        end
      end
      
      def send_to_non_cached_proxy(method, *args, &block)
        non_cached_proxy.send(method, *args, &block)
      end      
    end
  end
end