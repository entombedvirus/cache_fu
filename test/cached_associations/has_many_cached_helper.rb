require File.join(File.dirname(__FILE__), 'helper')

module HasManyCachedSpecSetup
  class User < MockActiveRecord::Base
    attr_accessor :id, :name
    
    def self.has_many(association_id, options = {}, &extension)
      reflection = Object.new
      
      reflection.stubs(:name).returns(association_id)
      reflection.stubs(:options).returns(options)
      reflection.stubs(:primary_key_name).returns("user_id")
      reflection.stubs(:klass).returns(Cat)
      reflection.stubs(:active_record).returns(User)
      
      reflections[association_id] = reflection
      
      # proxy = Object.new
      # proxy.define_method(:<<) do |obj|
      #   options[:after_add].call(obj) if options[:after_add]
      # end
      # define_method(reflection.name) do
      #   proxy
      # end
    end
  end
  
  class Cat < MockActiveRecord::Base
    %w(before_save after_destroy).each do |callback|
      eval <<-"end_eval"
        def self.#{callback}(&block)
          @#{callback}_callbacks ||= []
          @#{callback}_callbacks << block if block_given?
          @#{callback}_callbacks
        end
      end_eval
    end
    
    attr_accessor :id, :name, :user_id

    def save
      self.class.before_save.each {|cb| cb.call(self) }
    end
    
    def destroy
      self.class.after_destroy.each {|cb| cb.call(self) }
    end
  end
  
  [User, Cat].each do |klass|
    klass.extend ActsAsCached::CacheAssociations::ClassMethods
    klass.send :include, ActsAsCached::MarshallingMethods
  end
  
  def self.included(base)
    base.setup do 
      Cat.before_save.clear
      Cat.after_destroy.clear
      setup_cache_spec 
    end    
  end

  def setup_cache_spec
    @user = User.new(:id => 1, :name => "Bob")
    @siqi = User.new(:id => 2, :name => "Siqi")
    @cats = [Cat.new(:id => 1, :name => "Chester", :user_id => 1), Cat.new(:id => 2, :name => "Rob", :user_id => 1)]
    
    $with_memcache ? with_memcache : with_mock
    
    @user.stubs(:cat_ids).returns([1, 2])
    Cat.stubs(:find).with(%w(1 2)).returns(@cats)
    User.stubs(:find).with(1).returns(@user)
    User.stubs(:find).with(2).returns(@siqi)
  end

  def with_memcache
    unless $mc_setup_for_has_many_through_cache_spec
      ActsAsCached.config.clear
      config                                    = YAML.load_file(DEFAULT_CONFIG_FILE)
      config['test']                            = config['development'].merge('benchmarking' => false, 'disabled' => false)
      ActsAsCached.config                       = config
      $mc_setup_for_has_many_through_cache_spec = true
    end

    User.send(:acts_as_cached)
    User.send(:has_many_cached, :cats)
    Cat.send(:acts_as_cached)
  end

  def with_mock
    $cache.clear

    User.send(:acts_as_cached, :store => $cache)
    User.send(:has_many_cached, :cats)
    Cat.send(:acts_as_cached, :store => $cache)
  end
end

