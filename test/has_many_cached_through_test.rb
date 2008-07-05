require File.join(File.dirname(__FILE__), 'helper')
require File.join(File.dirname(__FILE__), 'has_many_cached_through_helper')
 
context "A Ruby class acting as cached with a has_many_cached :through association" do
  include HasManyCachedThroughSpecSetup
  
  specify "should be able to retrieve associations from cache" do
    HasManyCachedThroughSpecSetup::Cat.expects(:get_caches).with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal @cats
    @user.should.have.cached "cat_ids"
  end

  specify "should be able to set associations to cache if not already set when getting" do
    @user.should.not.have.cached "cat_ids"
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached "cat_ids"
  end 
  
  specify "should not set associations to the cache if is already set when getting" do
    @user.class.stubs(:cache_store).with(:get, "User:1:cat_ids").returns([1, 2])
    @user.class.expects(:cache_store).with(:set, "User:1:cat_ids").never
    @user.cached_cats.should.equal(@cats)
  end

  specify "should cache an empty array if the association is empty" do
    @user.stubs(:cat_ids).returns([])    
    @user.cached_cats.should.equal([])
    @user.get_cache("cat_ids").should.equal([])
  end

  specify "should update the cached ids list if a member is added to the association using association proxy" do
    @user.cached_cats.should.equal(@cats)
    @user.get_cache("cat_ids").should.equal([1, 2])
    
    new_cat = HasManyCachedThroughSpecSetup::Cat.new(:id => 3, :name => "Whiskers")
    
    @user.cats << new_cat
    @user.get_cache("cat_ids").should.equal([1, 2, 3])
  end

  specify "should update the cached ids list if a member is removed from the association using association proxy" do
    @user.cached_cats.should.equal(@cats)
    @user.get_cache("cat_ids").should.equal([1, 2])
    
    @user.cats.destroy @cats.first
    @user.get_cache("cat_ids").should.equal([2])
  end

  specify "should update the cached ids list if a member is added to the association NOT using association proxy" do
    @user.cached_cats.should.equal(@cats)
    @user.get_cache("cat_ids").should.equal([1, 2])
    
    new_ownership = HasManyCachedThroughSpecSetup::Ownership.new(:user_id => 1, :cat_id => 3)
    new_ownership.stubs(:changes).returns({"user_id" => [nil, 1], "cat_id" => [nil, 3]})
    new_ownership.save
    
    @user.get_cache("cat_ids").should.equal([1, 2, 3])
  end

  specify "should update the cached ids list if a member is removed from the association NOT using association proxy" do
    @user.cached_cats.should.equal(@cats)
    @user.get_cache("cat_ids").should.equal([1, 2])
    
    @ownerships.first.destroy
    
    @user.get_cache("cat_ids").should.equal([2])
  end
  
  specify "should not consult memcached on every invocation" do
    HasManyCachedThroughSpecSetup::Cat.expects(:get_caches).once.with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal(@cats)
    4.times {@user.cached_cats.should.equal(@cats)}
  end
  
  specify "can be forced to reload already cached cats from memcache" do
    HasManyCachedThroughSpecSetup::Cat.expects(:get_caches).times(5).with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal(@cats)
    4.times {@user.cached_cats(true).should.equal(@cats)}
  end
end