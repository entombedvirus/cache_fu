require File.join(File.dirname(__FILE__), 'test_helper')

context "An ActiveRecord class acting as cached" do
  
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
    
    @cats = [Cat.new(:name => "Chester", :user_id => 1), Cat.new(:name => "Fluffy", :user_id => 1)]
    @cats[0].id = 1; @cats[0].save
    @cats[1].id = 2; @cats[1].save
  end
  
  specify "should only save the attributes when marshalling" do
    @user.cats.size.should.equal(2)
    @user.marshal_dump.should.equal(@user.attributes)
  end
  
  specify "should construct the object back from marshalled data" do
    str = Marshal.dump(@user)
    Marshal.load(str).should.equal(@user)
  end
end