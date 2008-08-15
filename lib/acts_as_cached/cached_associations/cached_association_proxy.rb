module ActsAsCached
  module CachedAssociations
    class CachedAssociationProxy
      attr_reader :reflection
      alias_method :proxy_respond_to?, :respond_to?
      alias_method :proxy_extend, :extend
      delegate :to_param, :to => :proxy_target
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_)/ }

      def initialize(owner, reflection)
        @owner, @reflection = owner, reflection
        reset
      end

      def reset
        @loaded = false
        @target = nil
      end

      def loaded?
        @loaded
      end

      def loaded
        @loaded = true
      end

      def reload
        reset
        load_target
        self unless @target.nil?
      end

      def target
        @target
      end

      def target=(target)
        @target = target
        loaded
      end

      def inspect
        reload unless loaded?
        @target.inspect
      end

      def cache_key
        "#{@owner.cache_key}:#{@reflection.name}"
      end

      private

      def method_missing(method, *args, &block)
        if load_target
          @target.send(method, *args, &block)
        end
      end

      # Overload this method in specific implementations, like HasManyCachedProxy
      def load_target
        raise "Does not how to load target from within CachedAssociationProxy"
      end
    end
  end
end