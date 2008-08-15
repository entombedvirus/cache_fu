module ActsAsCached
  module CachedAssociations
    class HasManyCachedProxy < CachedAssociationProxy

      private

      def load_target
        return true if loaded?

        self.target = if (associates = @owner.cached_associations[@reflection.name]) # Check the instance cache first
          associates

        elsif (associate_ids = @owner.class.cache_store(:get, self.cache_key)) # Then the cache_store
          @reflection.klass.get_caches(associate_ids)

        else # And finally the database
          associates = @owner.send(@reflection.name)
          associate_ids = associates.collect(&:id)
          @owner.class.cache_store(:set, self.cache_key, associate_ids) unless associate_ids.blank?
          associates
        end

        # Update the instance cache
        @owner.cached_associations[@reflection.name] = self.target
        self.loaded
      end
    end
  end
end