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
# Lazy update patch
module ActiveRecord
  module Changed
    def self.included(base)
      base.alias_method_chain :write_attribute, :changed
      base.alias_method_chain :update_without_timestamps, :changed
      base.alias_method_chain :save_with_validation, :changed
      base.alias_method_chain :save_with_validation!, :changed
      base.alias_method_chain :create, :changed
    end
    
    def changes
      @changes ||= {}.with_indifferent_access
    end

    private

    def write_attribute_with_changed(attr_name, value)
      # If you're accessing attr= method, you should change the value ;-)
      changes[attr_name] = [read_attribute(attr_name.to_s), value]
      changed_attributes << attr_name.to_s
      write_attribute_without_changed(attr_name, value)
    end
    
    def update_without_timestamps_with_changed      
      quoted_attributes = attributes_with_quotes(false, false)
      quoted_attributes.reject! { |key, value| !changed_attributes.include?(key.to_s)}
      return 0 if quoted_attributes.empty?
      connection.update(
                    "UPDATE #{self.class.quoted_table_name} " +
                    "SET #{quoted_comma_pair_list(connection, quoted_attributes)} " +
                    "WHERE #{connection.quote_column_name(self.class.primary_key)} " +
                    "= #{quote_value(id)}",
                    "#{self.class.name} Update"
      )
    ensure
      changed_attributes.clear
    end
    
    def changed_attributes
      @changed_attributes ||= Set.new
    end

    def create_with_changed
      create_without_changed
    ensure
      changed_attributes.clear
    end
    
    def save_with_validation_with_changed
      save_with_validation_without_changed 
    ensure 
      changed_attributes.clear
    end

    def save_with_validation_with_changed!
      save_with_validation_without_changed! 
    ensure 
      changed_attributes.clear
    end

  end
end

ActiveRecord::Base.send :include, ActiveRecord::Changed

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

# test/spec/mini
def context(*args, &block)
  return super unless (name = args.first) && block
  require 'test/unit'
  klass = Class.new(Test::Unit::TestCase) do
    def self.specify(name, &block) define_method("test_#{name.gsub(/\W/,'_')}", &block) end
    def self.xspecify(*args) end
    def self.setup(&block) 
      define_method(:setup, &block) 
    end
    def self.teardown(&block) 
      define_method(:teardown, &block) 
    end
  end
  klass.class_eval &block
end

class User < ActiveRecord::Base
end

class Cat < ActiveRecord::Base
end

class Ownership < ActiveRecord::Base
end
