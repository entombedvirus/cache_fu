require File.join(File.dirname(__FILE__), 'helper')
require File.join(File.dirname(__FILE__), 'has_many_cached_helper')

context "A User class acting as cached with has_many_cached :cats" do
  include HasManyCachedSpecSetup
  
  specify "should be able to retrieve cats from cache" do
    HasManyCachedSpecSetup::Cat.expects(:get_caches).with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal @cats
    @user.should.have.cached "cat_ids"
  end
  
  specify "should be able to set cats to cache if not already set when getting" do
    @user.should.not.have.cached "cat_ids"
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached "cat_ids"
  end
  
  specify "should not set cats to the cache if is already set when getting" do
    @user.class.stubs(:cache_store).with(:get, "User:1:cat_ids").returns([1, 2])
    @user.class.expects(:cache_store).with(:set, "User:1:cat_ids").never
    @user.cached_cats.should.equal(@cats)
  end
  
  specify "should cache an empty array if the user does not have any cats" do
    @user.stubs(:cat_ids).returns([])    
    @user.cached_cats.should.equal([])
    @user.get_cache("cat_ids").should.equal([])
  end
    
  specify "should update the cached cat ids list when a Cat instance is saved" do
    @user.cached_cats.should.equal(@cats)
    @user.get_cache("cat_ids").should.equal([1, 2])
    
    new_cat = HasManyCachedSpecSetup::Cat.new(:id => 3, :name => "Whiskers", :user_id => 1)
    new_cat.stubs(:changes).returns({"user_id" => [nil, 1]})
    new_cat.save
    
    @user.get_cache("cat_ids").should.equal([1, 2, 3])
  end

  specify "should update the cached cat ids list when a cat instance is destroyed" do
    @user.cached_cats.should.equal(@cats)
    @user.get_cache("cat_ids").should.equal([1, 2])
    @cats.first.destroy
    @user.get_cache("cat_ids").should.equal([2])
  end

  specify "should not cause a user's entire cat list to be queried upon the save of an individual Cat object" do
    @siqi.should.not.have.cached "cat_ids"
    
    @siqi.expects(:cat_ids).never
    new_cat = HasManyCachedSpecSetup::Cat.new(:id => 3, :name => "Man Eating Cat", :user_id => 2)
    new_cat.stubs(:changes).returns({"user_id" => [nil, 1]})
    new_cat.save
    
    @siqi.should.not.have.cached "cat_ids"
  end
  
  specify "should not cause a user's entire cat list to be queried upon the destroy of an individual Cat object" do
    @siqi.should.not.have.cached "cat_ids"
    
    @siqi.expects(:cat_ids).never
    new_cat = HasManyCachedSpecSetup::Cat.new(:id => 3, :name => "Man Eating Cat", :user_id => 2)
    new_cat.destroy
    
    @siqi.should.not.have.cached "cat_ids"
  end

  specify "should update the old user's cached cat ids list when a cat is given to another user" do
    @user.cached_cat_ids.should.equal([1, 2])
    @siqi.stubs(:cat_ids).returns([])
    @siqi.cached_cat_ids.should.equal([])
    
    bobs_cat = @cats.first
    bobs_cat.user_id = @siqi.id
    bobs_cat.stubs(:changes).returns("user_id" => [1, 2])
    bobs_cat.save
    
    @user.cached_cat_ids.should.equal([2])
    @siqi.cached_cat_ids.should.equal([1])
  end
  
  specify "should not consult memcached on every invocation" do
    HasManyCachedSpecSetup::Cat.expects(:get_caches).once.with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal(@cats)
    4.times {@user.cached_cats.should.equal(@cats)}
  end
  
  specify "can be forced to reload already cached cats from memcache" do
    HasManyCachedSpecSetup::Cat.expects(:get_caches).times(5).with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal(@cats)
    4.times {@user.cached_cats(true).should.equal(@cats)}
  end
end
