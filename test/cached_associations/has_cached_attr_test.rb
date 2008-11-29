require File.join(File.dirname(__FILE__), 'test_helper')

User.class_eval <<-END_EVAL
  acts_as_cached :store => $cache
  has_cached_attr :achievement_points, 200
  has_cached_attr :rank, proc {|i| i.id * 1000}
END_EVAL

context "A class with has_cached_attr" do
  setup do
    User.delete_all
    $cache.clear
    
    @user  = User.new(:name => "Bob")
    @user.id = 1; @user.save
    
    @siqi = User.new(:name => "Siqi")
    @siqi.id = 2; @siqi.save
  end
  
  specify "should raise an exception if the instance was not loaded from cache" do
    proc {
      User.new.cached_attrs[:achievement_points]
    }.should.raise RuntimeError
  end
  
  specify "should provide the default value if the value was missing in cache" do
    User.get_cache(2).cached_attrs[:achievement_points].should.equal 200
  end
  
  specify "should retrieve modified cached attr value" do
    u = User.get_cache(1)
    u.cached_attrs[:rank].should.equal 1000

    u.cached_attrs[:rank] = 2000
    u.set_cache
    
    User.get_cache(u.id).cached_attrs[:rank].should.equal 2000
  end
end