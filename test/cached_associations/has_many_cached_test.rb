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
    User.cached_reflections[:cats].should.be.a.kind_of ActsAsCached::CachedAssociationReflection
  end
  
  specify "should be able to retrieve cats from cache" do
    @user.cached_cats.should.equal(@cats)
    @user.should.have.cached("cats")
  end
end