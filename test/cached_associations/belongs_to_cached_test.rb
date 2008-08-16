require File.join(File.dirname(__FILE__), 'test_helper')

User.class_eval <<-END_EVAL
  acts_as_cached :store => $cache
END_EVAL

Cat.class_eval <<-END_EVAL
  acts_as_cached :store => $cache
  belongs_to_cached :user
END_EVAL

context "A Cat class belongs_to_cached :user" do
  setup do
    $cache.clear
    User.delete_all
    Cat.delete_all

    @user  = User.new(:name => "Bob")
    @user.id = 1
    @user.save!
    
    @cat = Cat.new(:name => "Chester", :user_id => 1)
    @cat.id = 1
    @cat.save!
    
    @cat_with_bad_key = Cat.new(:name => "Felix", :user_id => 12)
    @cat_with_bad_key.save!
  end
  
  specify "should load the owner from cache" do
    @user.should.not.be.cached
    @cat.cached_user.should.equal(@user)
    @user.should.be.cached
  end
  
  specify "should not consult memcached on every invocation" do
    User.expects(:get_cache).once.with(1).returns(@user)
    4.times {@cat.cached_user.should.equal(@user)}
  end
  
  specify "can be forced to reload an already cached owner from memcache" do
    User.expects(:get_cache).times(5).with(1).returns(@user)
    5.times {@cat.cached_user(true).should.equal(@user)}
  end
  
  specify "should clear its instance association cache when reloaded" do
    @cat.cached_user.should.equal(@user)
    @cat.instance_variable_get(:@cached_user).should.equal(@user)
    @cat.reload
    @cat.instance_variable_get(:@cached_user).should.be.nil
  end
  
  specify "should not raise an exception if it cannot find the record for it's foreign key" do
    assert_nothing_raised do 
      @cat_with_bad_key.user
      @cat_with_bad_key.cached_user.should.equal(nil)
    end
  end
end
