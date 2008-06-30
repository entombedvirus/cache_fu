require File.join(File.dirname(__FILE__), 'helper')
require File.join(File.dirname(__FILE__), 'belongs_to_cached_helper')

context "A Cat class belongs_to_cached :user" do
  include BelongsToCachedSpecSetup
  
  specify "should load the owner from cache" do
    BelongsToCachedSpecSetup::User.expects(:get_cache).with(1).returns(@user)
    @cat.cached_user.should.equal @user
  end
end
