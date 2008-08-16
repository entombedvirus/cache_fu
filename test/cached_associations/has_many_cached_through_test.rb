require File.join(File.dirname(__FILE__), 'test_helper')

User.class_eval <<-END_EVAL
  acts_as_cached :store => $cache
  has_many :ownerships
  has_many_cached :cats, :through => :ownerships
END_EVAL

Cat.class_eval <<-END_EVAL
  acts_as_cached :store => $cache
END_EVAL

Ownership.class_eval <<-END_EVAL
  belongs_to :cat
  belongs_to :user
END_EVAL
 
context "A Ruby class acting as cached with a has_many_cached :through association" do
  setup do
    $cache.clear
    User.delete_all
    Cat.delete_all
    Ownership.delete_all

    @user  = User.new(:name => "Bob")
    @user.id = 1; @user.save
    
    
    @siqi = User.new(:name => "Siqi")
    @siqi.id = 2; @user.save
    
    @cats = [Cat.new(:name => "Chester"), Cat.new(:name => "Chester")]
    @cats[0].id = 1; @cats[0].save
    @cats[1].id = 2; @cats[1].save
        
    @ownerships = [Ownership.create(:user_id => 1, :cat_id => 1)]
    @ownerships << Ownership.create(:user_id => 1, :cat_id => 2)
  end
  
  specify "should be able to retrieve associations from cache" do
    @user.cached_cats.should.equal @cats
    @user.should.have.cached "cats"
  end

  specify "should be able to set associations to cache if not already set when getting" do
    @user.should.not.have.cached "cats"
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached "cats"
  end 
  
  specify "should not set associations to the cache if is already set when getting" do
    @user.cached_cats.should.equal(@cats)
    @user.class.expects(:cache_store).with(:set, "User:1:cats").never
    @user.cached_cats.should.equal(@cats)
  end

  specify "should cache an empty array if the association is empty" do
    @user.cached_cats.clear
    @user.cached_cats.should.equal([])
    User.fetch_cache("1:cats").should.equal([])
  end

  specify "should update the cached ids list if a member is added to the association using association proxy" do
    @user.cached_cats.should.equal(@cats)
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    new_cat = Cat.new(:name => "Whiskers")
    new_cat.id = 3
    new_cat.save
    
    @user.cats << new_cat
    User.fetch_cache("1:cats").should.equal([1, 2, 3])
  end

  specify "should update the cached ids list if a member is added to the association NOT using association proxy" do
    @user.cached_cats.should.equal(@cats)
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    new_ownership = Ownership.create(:user_id => 1, :cat_id => 3)
    
    User.fetch_cache("1:cats").should.equal([1, 2, 3])
  end

  specify "should update the cached ids list if a member is removed from the association NOT using association proxy" do
    @user.cached_cats.should.equal(@cats)
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    @ownerships.first.destroy
    
    User.fetch_cache("1:cats").should.equal([2])
  end
 
  specify "should update the cached ids list if a member is removed from the association using the association proxy" do
    @user.cached_cats.should.equal(@cats)
    User.fetch_cache("1:cats").should.equal([1, 2])
    
    @user.cached_cats.delete(@cats.first)
    User.fetch_cache("1:cats").should.equal([2])
    @user.cached_cats.should.equal([@cats[1]])
  end
  
  specify "should not consult memcached on every invocation" do
    @user.cached_cats.should.equal(@cats)
    
    Cat.expects(:get_caches).never 
    4.times {@user.cached_cats.should.equal(@cats)}
  end
  
  specify "can be forced to reload already cached cats from memcache" do
    @user.cached_cats.should.equal(@cats)
    
    Cat.expects(:get_caches).times(4).with([1, 2]).returns({1 => @cats[0], 2 => @cats[1]})
    4.times {@user.cached_cats(true).should.equal(@cats)}
  end
  
  specify "should be able to override cached cat ids manually" do
    @user.cached_cats.should.equal(@cats)
    @user.cached_cat_ids.should.equal([1, 2])
    
    @other_cat = Cat.new(:name => "Man Eating Cat")
    @other_cat.id = 3
    @other_cat.save
    @user.cached_cat_ids = [3]
    
    @user.cached_cats.should.equal([@other_cat])
    # We're just changing the cache, the association in db should still point to the old cats
    @user.cat_ids.should.equal([1, 2])
  end
  
  specify "should clear its instance association cache when reloaded" do
    @user.cached_cats.should.equal(@cats)
    @user.reload
    
    Cat.expects(:get_caches).with([1, 2]).returns({1 => @cats[0], 2 => @cats[1]})
    @user.cached_cats.should.equal(@cats)
  end

  specify "should preserve duplicate cats owned through different ownerships" do
    # User 1 owns chester thru 2 different ownership instances
    new_ownership = Ownership.create(:user_id => 1, :cat_id => 1)
    
    @user.cached_cats.should.not.be.empty
    User.fetch_cache("1:cats").sort.should.equal([1, 1, 2])
    @user.cached_cats(true).size.should.equal(3)
  end
end