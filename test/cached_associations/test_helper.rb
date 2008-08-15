# require File.join(File.dirname(__FILE__), '../helper')
$LOAD_PATH.unshift "#{dir = File.dirname(__FILE__)}/../../lib"

begin
  require 'rubygems'
  require 'ruby-debug'
  gem 'mocha', '>= 0.4.0'
  gem 'activerecord', '= 2.0.2'
  gem 'activesupport', '= 2.0.2'
  require 'active_record'
  require 'active_support'
  require 'mocha'
  gem 'test-spec', '= 0.3.0'
  require 'test/spec'
  # require 'multi_rails_init'
rescue LoadError
  puts '=> acts_as_cached tests depend on the following gems: mocha (0.4.0+), test-spec (0.3.0), multi_rails (0.0.2), and rails.'
  raise
end

begin
  require 'redgreen'
rescue LoadError
  nil
end

Test::Spec::Should.send    :alias_method, :have, :be
Test::Spec::ShouldNot.send :alias_method, :have, :be

require 'acts_as_cached'

Object.send :include, ActsAsCached::Mixin

class HashStore < Hash
  alias :get :[]

  def get_multi(*values)
    reject { |k,v| !values.include? k }
  end

  def set(key, value, *others)
    self[key] = value
  end
  
  def namespace
    nil
  end
end

$cache = HashStore.new

Object.const_set(:RAILS_DEFAULT_LOGGER, Logger.new(STDOUT))
# ActiveRecord::Base.logger = RAILS_DEFAULT_LOGGER

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :dbfile => File.join(dir, 'db/master.db')

# # test/spec/mini
# def context(*args, &block)
#   return super unless (name = args.first) && block
#   require 'test/unit'
#   klass = Class.new(Test::Unit::TestCase) do
#     def self.specify(name, &block) define_method("test_#{name.gsub(/\W/,'_')}", &block) end
#     def self.xspecify(*args) end
#     def self.setup(&block) 
#       define_method(:setup, &block) 
#     end
#     def self.teardown(&block) 
#       define_method(:teardown, &block) 
#     end
#   end
#   klass.class_eval &block
# end

class User < ActiveRecord::Base
end

class Cat < ActiveRecord::Base
end

class Ownership < ActiveRecord::Base
end
