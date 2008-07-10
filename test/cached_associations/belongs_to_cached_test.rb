require File.join(File.dirname(__FILE__), 'belongs_to_cached_helper')

context "A Cat class belongs_to_cached :user" do
  include BelongsToCachedSpecSetup
  
  setup do
    User.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
    END_EVAL
    
    Cat.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
      belongs_to_cached :user
    END_EVAL
    
    @user  = User.new(:name => "Bob")
    @cat = Cat.new(:name => "Chester", :user_id => 1)
    Cat.stubs(:find).returns(@cat)
    User.stubs(:find).returns(@user)
  end
  
  specify "should load the owner from cache" do
    User.expects(:get_cache).with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
  end
  
  specify "should not consult memcached on every invocation" do
    User.expects(:get_cache).once.with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
    4.times {@cat.cached_user.should.equal(@user)}
  end
  
  specify "can be forced to reload an already cached owner from memcache" do
    User.expects(:get_cache).times(5).with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
    4.times {@cat.cached_user(true).should.equal(@user)}
  end
  
  specify "should clear its instance association cache when reloaded" do
    User.expects(:get_cache).times(2).with(1).returns(@user)
    
    @cat.cached_user.should.equal(@user)
    @cat.reload
    @cat.cached_user.should.equal(@user)
  end
end
