require File.join(File.dirname(__FILE__), 'test_helper')

context "A User class acting as cached with a has_many_cached :cats" do

  setup do
    User.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
      has_one_cached :cat
    END_EVAL

    Cat.class_eval <<-END_EVAL
      acts_as_cached :store => $cache
    END_EVAL

    @user  = User.new(:name => "Bob")
    @user.id = 1
    @user.stubs(:cat_id).returns(1)

    @siqi = User.new(:name => "Siqi")
    @siqi.id = 2

    @cat = Cat.new(:name => "Chester", :user_id => 1)
    @cat.id = 1

    Cat.stubs(:find).returns(@cat)
    User.stubs(:find).returns(@user)

    $cache.clear
    User.delete_all
    Cat.delete_all
  end

  specify "should be able to retrieve cat from cache" do
    Cat.expects(:get_cache).with(1).returns(@cat)
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

  specify "should not cache anything if the user does not have a cat" do
    @user.stubs(:cat_id).returns(nil)
    @user.cached_cat.should.equal(nil)
    @user.should.not.have.cached "cat_id"
  end

  specify "should update the cached cat id when a Cat instance is saved" do
    @user.cached_cat.should.equal(@cat)

    new_cat = Cat.new(:name => "Whiskers", :user_id => 1)
    new_cat.id = 3
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
    new_cat = Cat.new(:name => "Man Eating Cat", :user_id => 2)
    new_cat.stubs(:changes).returns({"user_id" => [nil, 1]})
    new_cat.save

    @siqi.should.not.have.cached "cat_id"
  end

  specify "should not cause a user's cat id to be queried upon the destroy of an individual Cat object" do
    @siqi.should.not.have.cached "cat_id"

    @siqi.expects(:cat_ids).never
    new_cat = Cat.new(:name => "Man Eating Cat", :user_id => 2)
    new_cat.destroy

    @siqi.should.not.have.cached "cat_id"
  end

  specify "should remove the old user's cached cat id when a cat is given to another user" do
    @user.cached_cat_id.should.equal(1)
    @siqi.stubs(:cat_id).returns(nil)
    @siqi.cached_cat_id.should.equal(nil)

    bobs_cat = Cat.new(:name => "Bob's cat")
    bobs_cat.user_id = @siqi.id
    bobs_cat.stubs(:changes).returns("user_id" => [1, 2])
    bobs_cat.save

    @user.should.not.have.cached "cat_id"
  end

  specify "should not consult memcached on every invocation" do
    Cat.expects(:get_cache).once.with(1).returns(@cat)
    @user.cached_cat.should.equal(@cat)
    4.times {@user.cached_cat.should.equal(@cat)}
  end

  specify "can be forced to reload an already cached cat from memcache" do
    Cat.expects(:get_cache).times(5).with(1).returns(@cat)
    @user.cached_cat.should.equal(@cat)
    4.times {@user.cached_cat(true).should.equal(@cat)}
  end

  specify "should be able to override cached cat ids manually" do
    @user.cached_cat.should.equal(@cat)
    @user.cached_cat_id.should.equal(1)

    @other_cat = Cat.new(:name => "Man Eating Cat", :user_id => 1)
    Cat.expects(:get_cache).with(2).returns(@other_cat)
    @user.cached_cat_id = 2

    @user.cached_cat.should.equal(@other_cat)
    # We're just changing the cache, the association in db should still point to the old cat
    @user.cat_id.should.equal(1)
  end

  specify "should clear its instance association cache when reloaded" do
    Cat.expects(:get_cache).times(2).with(1).returns(@cat)

    @user.cached_cat.should.equal(@cat)
    @user.reload
    @user.cached_cat.should.equal(@cat)
  end
end

