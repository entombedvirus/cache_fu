require File.join(File.dirname(__FILE__), 'test_helper')

context "User.has_many_cached :cats" do
  setup do
    $cache.clear
    User.delete_all
    Cat.delete_all
    
    User.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
      has_many_cached :cats
    END_EVAL
    
    Cat.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
    END_EVAL
    
    @user  = User.new(:name => "Bob")
    @user.id = 1; @user.save
    
    
    @siqi = User.new(:name => "Siqi")
    @siqi.id = 2; @user.save
    
    @cats = [Cat.new(:name => "Chester", :user_id => 1), Cat.new(:name => "Chester", :user_id => 1)]
    @cats[0].id = 1; @cats[0].save
    @cats[1].id = 2; @cats[1].save
  end
  
  specify "should be able to enumerate cached association reflections" do
    User.cached_reflections.keys.should.include :cats
    User.cached_reflections[:cats].should.be.a.kind_of ActsAsCached::CachedAssociations::HasManyCachedReflection
  end
  
  specify "should be able to retrieve cats from cache" do
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached("cats")
  end
  
  specify "should be able to set cats to cache if not already set when getting" do
    @user.should.not.have.cached "cats"
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached "cats"
  end
  
  specify "should not set cats to the cache if is already set when getting" do
    @user.cached_cats.should.equal(@cats)
    @user.class.expects(:cache_store).with(:set, "User:1:cats").never
    @user.cached_cats.should.equal(@cats)
  end
  
  specify "should cache an empty array if the user does not have any cats" do
    @user.cats.delete_all
    @user.cached_cats.should.equal([])
    @user.class.fetch_cache("1:cats").should.equal([])
  end
  
  specify "should update the cached cat ids list when a Cat instance is saved" do
    @user.cached_cats.should.equal(@cats)
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    new_cat = Cat.new(:name => "Whiskers", :user_id => 1)
    new_cat.id = 3
    new_cat.save
    
    User.fetch_cache("1:cats").should.equal([1, 2, 3])
  end

  specify "should update the cached cat ids list when a cat instance is destroyed" do
    @user.cached_cats.should.equal(@cats)
    User.fetch_cache("1:cats").should.equal([1, 2])
    @cats.first.destroy
    User.fetch_cache("1:cats").should.equal([2])
  end

  specify "should not cause a user's entire cat list to be queried upon the save of an individual Cat object" do
    @siqi.should.not.have.cached "cats"
    
    @siqi.expects(:cats).never
    new_cat = Cat.create(:name => "Man Eating Cat", :user_id => 2)
    
    @siqi.should.not.have.cached "cats"
  end
  
  specify "should not cause a user's entire cat list to be queried upon the destroy of an individual Cat object" do
    @siqi.should.not.have.cached "cats"
    
    @siqi.expects(:cats).never
    new_cat = Cat.create(:name => "Man Eating Cat", :user_id => 2)
    new_cat.destroy
    
    @siqi.should.not.have.cached "cats"
  end
  
  specify "should update the old user's cached cat ids list when a cat is given to another user" do
    @user.cached_cat_ids.should.equal([1, 2])
    @siqi.cached_cat_ids.should.equal([])
    
    bobs_cat = @cats.first
    bobs_cat.user_id = @siqi.id
    bobs_cat.save
    
    @user.cached_cat_ids.should.equal([2])
    @siqi.cached_cat_ids.should.equal([1])
  end
  
  specify "should not consult memcached on every invocation when it doesn't have to go to the DB" do
    # prime the cache_store
    @user.cached_cats.should.equal(@cats)
    # clear the instance cache
    @user.clear_association_cache
    
    Cat.expects(:get_caches).once.returns({1 => @cats[0], 2 => @cats[1]})
    4.times {@user.cached_cats.should.equal(@cats)}
  end

  specify "can be forced to reload already cached cats from memcache" do
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached "cats"
    
    Cat.expects(:get_caches).times(4).with([1, 2]).returns({1 => @cats[0], 2 => @cats[1]})
    4.times {@user.cached_cats(true).should.equal(@cats)}
  end
  
  specify "should be able to override cached cat ids manually" do
    @user.cached_cats.should.equal(@cats)
    @user.cached_cat_ids.should.equal([1, 2])
    
    @other_cat = Cat.new(:name => "Man Eating Cat", :user_id => nil)
    @other_cat.id = 3
    @other_cat.save
    @user.cached_cat_ids = [3]
    @user.cached_cats.should.equal([@other_cat])
    # We're just changing the cache, the association in db should still point to the old cats
    @user.cat_ids.should.equal([1, 2])
  end
  
  specify "should clear its instance association cache when reloaded" do
    @user.cached_cats.should.equal(@cats)
    @user.cached_cats.loaded?.should.be true
    @user.reload
    @user.cached_cats.loaded?.should.be false
  end
  
  specify "should not allow :order and :limit as options" do
    class Owner < ActiveRecord::Base
      acts_as_cached :store => $cache
    end
    class Thing < ActiveRecord::Base
      acts_as_cached :store => $cache
    end
    
    proc { Owner.has_many_cached :things, :order => "id DESC" }.should.raise(RuntimeError)
    proc { Owner.has_many_cached :things, :limit => 15 }.should.raise(RuntimeError)
  end
  
  specify "should update the cached cats list when a cat is added thru the association proxy" do
    @user.cached_cats.should.equal @cats
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    new_cat = Cat.new(:name => "John")
    new_cat.id = 3
    @user.cached_cats << new_cat
    @user.cached_cats.should.equal(@cats + [new_cat])
    User.fetch_cache("1:cats").should.equal([1, 2, 3])
    
    another_cat = @user.cached_cats.create(:name => "Garry")
    @user.cached_cats.should.equal(@cats + [new_cat, another_cat])
    User.fetch_cache("1:cats").should.equal([1, 2, 3, another_cat.id])
  end
  
  specify "should update the cached cats list when a cat is removed thru the association proxy" do
    @user.cached_cats.should.equal @cats
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    @user.cached_cats.delete(@cats.first)
    @user.cached_cats.should.equal([@cats[1]])
    User.fetch_cache("1:cats").should.equal([2])
  end  
end