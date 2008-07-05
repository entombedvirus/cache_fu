require File.join(File.dirname(__FILE__), 'helper')
require File.join(File.dirname(__FILE__), 'belongs_to_cached_helper')

context "A Cat class belongs_to_cached :user" do
  include BelongsToCachedSpecSetup
  
  specify "should load the owner from cache" do
    BelongsToCachedSpecSetup::User.expects(:get_cache).with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
  end
  
  specify "should not consult memcached on every invocation" do
    BelongsToCachedSpecSetup::User.expects(:get_cache).once.with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
    4.times {@cat.cached_user.should.equal(@user)}
  end
  
  specify "can be forced to reload an already cached owner from memcache" do
    BelongsToCachedSpecSetup::User.expects(:get_cache).times(5).with(1).returns(@user)
    @cat.cached_user.should.equal(@user)
    4.times {@cat.cached_user(true).should.equal(@user)}
  end
end
