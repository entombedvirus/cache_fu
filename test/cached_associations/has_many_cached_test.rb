require File.join(File.dirname(__FILE__), 'test_helper')

context "A User class acting as cached with has_many_cached :cats" do
  
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
  
  specify "should be able to retrieve cats from cache" do
    Cat.expects(:get_caches).with([1, 2]).returns(@cats)
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
    
    new_cat = Cat.new(:name => "Whiskers", :user_id => 1)
    new_cat.id = 3
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
    new_cat = Cat.create(:name => "Man Eating Cat", :user_id => 2)
    
    @siqi.should.not.have.cached "cat_ids"
  end
  
  specify "should not cause a user's entire cat list to be queried upon the destroy of an individual Cat object" do
    @siqi.should.not.have.cached "cat_ids"
    
    @siqi.expects(:cat_ids).never
    new_cat = Cat.create(:name => "Man Eating Cat", :user_id => 2)
    new_cat.destroy
    
    @siqi.should.not.have.cached "cat_ids"
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
  
  specify "should not consult memcached on every invocation" do
    Cat.expects(:get_caches).once.with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal(@cats)
    4.times {@user.cached_cats.should.equal(@cats)}
  end
  
  specify "can be forced to reload already cached cats from memcache" do
    Cat.expects(:get_caches).times(5).with([1, 2]).returns(@cats)
    @user.cached_cats.should.equal(@cats)
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
    Cat.expects(:get_caches).times(2).with([1, 2]).returns(@cats)
    
    @user.cached_cats.should.equal(@cats)
    @user.reload
    @user.cached_cats.should.equal(@cats)
  end
  
  specify "should not allow :order and :limit as options" do
    class Owner < ActiveRecord::Base
      acts_as_cached :store => $cache
    end
    
    proc { Owner.has_many_cached :things, :order => "id DESC" }.should.raise(RuntimeError)
    proc { Owner.has_many_cached :things, :limit => 15 }.should.raise(RuntimeError)
  end
  # specify "should update the cached cats list when a cat is added thru the association proxy" do
  #   @user.cached_cats.should.equal @cats
  #   @user.class.fetch_cache("1:cat_ids").should.equal([1, 2])
  #   
  #   new_cat = Cat.new(:name => "John")
  #   @user.cats << new_cat
  #   
  #   @user.cached_cats(true).should.equal(@cats + [new_cat])
  # end
  # specify "should update the cached cats list when a cat is removed thru the association proxy"
end
