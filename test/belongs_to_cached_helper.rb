module BelongsToCachedSpecSetup
  class User
    def self.name
      "User"
    end
    
    def self.reflections
      @reflections ||= {}
      @reflections
    end
        
    attr_accessor :id, :name

    def initialize(attributes = {})
      attributes.each { |key, value| instance_variable_set("@#{key}", value) }
    end
    
  end
  
  class Cat
    def self.name
      "Cat"
    end
    
    def self.reflections
      @reflections ||= {}
      @reflections
    end
    
    def self.belongs_to(association_id, options = {}, &extension)
      reflection = Object.new
      
      reflection.stubs(:name).returns(association_id)
      reflection.stubs(:options).returns(options)
      reflection.stubs(:primary_key_name).returns("user_id")
      reflection.stubs(:klass).returns(User)
      reflection.stubs(:active_record).returns(Cat)
      
      reflections[association_id] = reflection
    end    
    
    attr_accessor :id, :name, :user_id

    def initialize(attributes = {})
      attributes.each { |key, value| instance_variable_set("@#{key}", value) }
    end
  end
  
  def self.included(base)
    base.setup do 
      setup_cache_spec 
    end    
  end

  def setup_cache_spec
    @user  = User.new(:id => 1, :name => "Bob")
    # @siqi = User.new(:id => 2, :name => "Siqi")
    
    @cat = Cat.new(:id => 1, :name => "Chester", :user_id => 1)
    
    # $stories = { 1 => @story, 2 => @story2, 3 => @story3 }

    $with_memcache ? with_memcache : with_mock
    
    # @user.stubs(:cat_id).returns(1)
    Cat.stubs(:find).with(1).returns(@cat)
    User.stubs(:find).with(1).returns(@user)
    # User.stubs(:find).with(2).returns(@siqi)
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

    User.send(:acts_as_cached, :store => $cache)
    Cat.send(:acts_as_cached, :store => $cache)
    Cat.send(:belongs_to_cached, :user)
  end
  
end
