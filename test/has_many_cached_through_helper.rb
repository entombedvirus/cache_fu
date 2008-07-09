require File.join(File.dirname(__FILE__), 'helper')

module HasManyCachedThroughSpecSetup
  class User < MockActiveRecord::Base
    attr_accessor :id, :name
    
    def self.has_many(association_id, options = {}, &extension)
      reflection = Object.new
      
      reflection.stubs(:name).returns(association_id)
      reflection.stubs(:options).returns(options)
      reflection.stubs(:primary_key_name).returns("user_id")
      reflection.stubs(:klass).returns(Cat)
      reflection.stubs(:active_record).returns(User)
      
      through_reflection = Object.new
      through_reflection.stubs(:primary_key_name).returns("user_id")
      through_reflection.stubs(:klass).returns(Ownership)
      reflection.stubs(:through_reflection).returns(through_reflection)
      
      source_reflection = Object.new
      source_reflection.stubs(:primary_key_name).returns("cat_id")
      reflection.stubs(:source_reflection).returns(source_reflection)
      
      
      reflections[association_id] = reflection
      
      define_method(association_id) do
        proxy = Object.new
        def proxy.<<(instance)
          ownership = Ownership.new(:user_id => 1, :cat_id => instance.id)
          ownership.stubs(:changes).returns("user_id" => [nil, 1], "cat_id" => [nil, instance.id])
          ownership.save
        end
        def proxy.destroy(instance)
          ownership = Ownership.new(:user_id => 1, :cat_id => instance.id)
          ownership.destroy
        end
        proxy
      end
    end
  end
  
  class Ownership < MockActiveRecord::Base
    attr_accessor :id, :user_id, :cat_id
    
    def self.belongs_to(association_id, options = {})
      reflection = Object.new
      
      reflections[association_id] = reflection
    end

    %w(before_save after_destroy).each do |callback|
      eval <<-"end_eval"
        def self.#{callback}(&block)
          @#{callback}_callbacks ||= []
          @#{callback}_callbacks << block if block_given?
          @#{callback}_callbacks
        end
      end_eval
    end
    
    def save
      self.class.before_save.first.call(self)
    end
    
    def destroy
      self.class.after_destroy.first.call(self)
    end    
  end
  
  class Cat < MockActiveRecord::Base
    attr_accessor :id, :name
  end

  [User, Cat, Ownership].each do |klass|
    klass.extend ActsAsCached::CacheAssociations::ClassMethods
    klass.send :include, ActsAsCached::MarshallingMethods
  end
    
  def self.included(base)
    base.setup do 
      Ownership.before_save.clear
      Ownership.after_destroy.clear
      setup_cache_spec 
    end    
  end

  def setup_cache_spec
    @user  = User.new(:id => 1, :name => "Bob")
    @ownerships = [Ownership.new(:id => 1, :user_id => 1, :cat_id => 1), Ownership.new(:id => 2, :user_id => 1, :cat_id => 2)]
    @cats = [Cat.new(:id => 1, :name => "Chester"), Cat.new(:id => 2, :name => "Rob")]
    
    # $stories = { 1 => @story, 2 => @story2, 3 => @story3 }

    $with_memcache ? with_memcache : with_mock
    
    @user.stubs(:cat_ids).returns([1, 2])
    Cat.stubs(:find).with(%w(1 2)).returns(@cats)
    User.stubs(:find).with(1).returns(@user)
  end

  # def with_memcache
  #   unless $mc_setup_for_has_many_through_cache_spec
  #     ActsAsCached.config.clear
  #     config = YAML.load_file(DEFAULT_CONFIG_FILE)
  #     config['test'] = config['development'].merge('benchmarking' => false, 'disabled' => false)
  #     ActsAsCached.config = config
  #     $mc_setup_for_has_many_through_cache_spec = true
  #   end
  # 
  #   Story.send :acts_as_cached
  #   Story.expire_cache(1)
  #   Story.expire_cache(2)
  #   Story.expire_cache(3)
  #   Story.expire_cache(:block)
  #   Story.set_cache(2, @story2)
  # end

  def with_mock
    $cache.clear

    Ownership.send(:belongs_to, :cat)
    Ownership.send(:belongs_to, :user)
    User.send(:has_many, :ownerships)
    User.send(:acts_as_cached, :store => $cache)
    User.send(:has_many_cached, :cats, :through => :ownerships)
    Cat.send(:acts_as_cached, :store => $cache)
  end
end