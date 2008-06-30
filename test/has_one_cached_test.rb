require File.join(File.dirname(__FILE__), 'helper')
require File.join(File.dirname(__FILE__), 'has_one_cached_helper')

context "A User class acting as cached with a has_many_cached :cats" do
  include HasOneCachedSpecSetup
  
  specify "should be able to retrieve cat from cache" do
      HasOneCachedSpecSetup::Cat.expects(:get_cache).with(1).returns(@cat)
      @user.cached_cat.should.equal @cat
      @user.should.have.cached "cat_id"
    end
    
    specify "should be able to set cat to cache if not already set when getting" do
      @user.should.not.have.cached "cat_id"
      @user.cached_cat.should.equal(@cat)
      @user.should.have.cached "cat_id"
    end
    
    specify "should not set cat to the cache if is already set when getting" do
      @user.class.stubs(:cache_store).with(:get, "User:1:cat_id").returns(1)
      @user.class.expects(:cache_store).with(:set, "User:1:cat_id").never
      @user.cached_cat.should.equal(@cat)
    end
    
    specify "should not cache anything if the user does have a cat" do
      @user.stubs(:cat_id).returns(nil)    
      @user.cached_cat.should.equal(nil)
      @user.should.not.have.cached "cat_id"
    end
    
  specify "should update the cached cat id when a Cat instance is saved" do
    @user.cached_cat.should.equal(@cat)
    
    new_cat = HasOneCachedSpecSetup::Cat.new(:id => 3, :name => "Whiskers", :user_id => 1)
    new_cat.stubs(:changes).returns({"user_id" => [nil, 1]})
    new_cat.save
    
    @user.class.fetch_cache("1:cat_id").should.equal(3)
  end

  specify "should update the cached cat id when a cat instance is destroyed" do
    @user.cached_cat.should.equal(@cat)
    @user.class.fetch_cache("1:cat_id").should.equal(1)
    @cat.destroy
    @user.class.fetch_cache("1:cat_id").should.equal(nil)
  end
  
  specify "should not cause a user's cat id to be queried upon the save of an individual Cat object" do
    @siqi.should.not.have.cached "cat_id"
    
    @siqi.expects(:cat_id).never
    new_cat = HasOneCachedSpecSetup::Cat.new(:id => 3, :name => "Man Eating Cat", :user_id => 2)
    new_cat.stubs(:changes).returns({"user_id" => [nil, 1]})
    new_cat.save
    
    @siqi.should.not.have.cached "cat_id"
  end
  
  specify "should not cause a user's cat id to be queried upon the destroy of an individual Cat object" do
    @siqi.should.not.have.cached "cat_id"
    
    @siqi.expects(:cat_ids).never
    new_cat = HasOneCachedSpecSetup::Cat.new(:id => 3, :name => "Man Eating Cat", :user_id => 2)
    new_cat.destroy
    
    @siqi.should.not.have.cached "cat_id"
  end
  
  specify "should remove the old user's cached cat id when a cat is given to another user" do
    @user.cached_cat_id.should.equal(1)
    @siqi.stubs(:cat_id).returns(nil)
    @siqi.cached_cat_id.should.equal(nil)
    
    bobs_cat = @cat
    bobs_cat.user_id = @siqi.id
    bobs_cat.stubs(:changes).returns("user_id" => [1, 2])
    bobs_cat.save
    
    @user.should.not.have.cached "cat_id"
  end
end

