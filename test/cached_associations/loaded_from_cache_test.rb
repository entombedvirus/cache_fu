require File.join(File.dirname(__FILE__), 'test_helper')

User.class_eval <<-END_EVAL
  acts_as_cached :store => $cache
END_EVAL

context "An object acting_as_cached" do
  setup do
    $cache.clear
    User.delete_all
        
    @user  = User.new(:name => "Bob")
    @user.id = 1; @user.save
    
    @siqi = User.new(:name => "Siqi")
    @siqi.id = 2; @siqi.save
  end
  
  specify "should know whether it was loaded from cache" do
    User.get_cache(1).should.be.loaded_from_cache
    User.find(1).should.not.be.loaded_from_cache
  end
  
  specify "should be consisered loaded from cache if it was just committed to cache" do
    u = User.find(1)
    u.should.not.be.loaded_from_cache
    u.set_cache
    u.should.be.loaded_from_cache
  end
  
  specify "should work with get_multi" do    
    users = User.get_caches([1, @siqi.id])
    users.values.each do |u|
      u.should.be.loaded_from_cache
    end
  end
  
  specify "should work with get_caches" do
    User.get_cache(1)
    users = User.get_caches([1, @siqi.id])
    users.values.each do |u|
      u.should.be.loaded_from_cache
    end
  end
end