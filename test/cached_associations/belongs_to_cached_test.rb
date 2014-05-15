require File.join(File.dirname(__FILE__), 'test_helper')

context "A Cat class belongs_to_cached :user" do
  setup do
    $cache.clear
    User.delete_all
    Cat.delete_all

    User.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
    END_EVAL

    Cat.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
      belongs_to_cached :user
    END_EVAL

    @user  = User.new(:name => "Bob")
    @cat = Cat.new(:name => "Chester", :user_id => 1)
    @cat_with_bad_key = Cat.new(:name => "Felix", :user_id => 12)
  end

  specify "should load the owner from cache" do
    Cat.stubs(:find).returns(@cat)
    User.stubs(:find).returns(@user)
    User.expects(:get_cache).with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
  end

  specify "should not consult memcached on every invocation" do
    Cat.stubs(:find).returns(@cat)
    User.stubs(:find).returns(@user)
    User.expects(:get_cache).once.with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
    4.times {@cat.cached_user.should.equal(@user)}
  end

  specify "can be forced to reload an already cached owner from memcache" do
    Cat.stubs(:find).returns(@cat)
    User.stubs(:find).returns(@user)
    User.expects(:get_cache).times(5).with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
    4.times {@cat.cached_user(true).should.equal(@user)}
  end

  specify "should clear its instance association cache when reloaded" do
    Cat.stubs(:find).returns(@cat)
    User.stubs(:find).returns(@user)
    User.expects(:get_cache).times(2).with(1).returns(@user)

    @cat.cached_user.should.equal(@user)
    @cat.reload
    @cat.cached_user.should.equal(@user)
  end

  specify "should not raise an exception if it cannot find the record for it's foreign key" do
    assert_nothing_raised do
      @cat_with_bad_key.user
      @cat_with_bad_key.cached_user.should.equal(nil)
    end
  end
end
