require File.dirname(__FILE__) + '/spec_helper.rb'

# replace_ant_style_property
describe String, " when calling replace_ant_style_property" do
  
  it "should return a string with the property replaced" do
    source = "Good ${greeting}"
    result = source.replace_ant_style_property("greeting", "Morning!")
    result.should eql("Good Morning!")
  end
  
  it "should return an unmodified string when the source doesn't contain the specified ant style property" do
    source = "Good Morning!"
    result = source.replace_ant_style_property("chunky", "bacon!")
    result.should eql("Good Morning!")
  end
end

# replace_ant_style_properties
describe String, " when calling replace_ant_style_properties" do
  
  it "should return a string with any given properties replaced" do
    source = "Good ${greeting}, ${state_of_world} World"
    result = source.replace_ant_style_properties({"greeting" => "Bye!", "state_of_world" => "Cruel"})
    result.should eql("Good Bye!, Cruel World")
  end
  
  it "should return an unmodified string when the source doesn't contain any of the specified ant style properties" do
    source = "Good Morning!"
    result = source.replace_ant_style_properties({"greeting" => "Bye!", "state_of_world" => "Cruel"})
    result.should eql("Good Morning!")
  end
end

# underscore_class_name
describe Class, " when calling underscore_class_name" do
  
  it "should return a valid underscore ruby identifier string" do
    class SomeClass; end
    sym = SomeClass.underscore_class_name
    sym.should eql("some_class")
  end
  
  it "should return a valid underscore ruby identifier string sans the module" do
    module Boo
      class SomeOtherClass; end;
    end
    sym = Boo::SomeOtherClass.underscore_class_name
    sym.should eql("some_other_class")
  end

  it "should return a valid underscore ruby identifier string for an annonymous class" do
    class TheParent; end
    TheParent.create_child "AnnonymousChild"
    sym = AnnonymousChild.underscore_class_name
    sym.should eql("annonymous_child")
  end
end

# class_to_sym
describe Class, " when calling class_to_sym" do
  
  it "should return a valid underscore ruby identifier as a symbol" do
    class SomeClass; end
    sym = SomeClass.class_to_sym
    sym.should eql(:some_class)
  end
  
  it "should return a valid underscore ruby identifier as a symbol sans the module" do
    module Boo
      class SomeOtherClass; end;
    end
    sym = Boo::SomeOtherClass.class_to_sym
    sym.should eql(:some_other_class)
  end

  it "should return a valid underscore ruby identifier as a symbol for an annonymous class" do
    class TheParent; end
    TheParent.create_child "AnotherAnnonymousChild"
    sym = AnotherAnnonymousChild.class_to_sym
    sym.should eql(:another_annonymous_child)
  end
end

# attr_array tests
describe "when calling attr_array", :shared => true do
  
  it "should create an empty array" do
    elements = @target.instance_eval { @elements }
    elements.should_not be_nil
    elements.should be_empty
  end
end

describe Class, " when calling attr_array with default options" do
  
  before :each do
    @target = Class.new
    @target.attr_array(:elements)
  end

  it_should_behave_like "when calling attr_array" 
  
  it "should create an accessor method for the array" do
    @target.should respond_to(:elements) 
  end
    
end

describe Class, " when calling attr_array with options {:create_accessor => false}" do

  before :each do
    @target = Class.new
    @target.attr_array(:elements, :create_accessor => false)    
  end
  
  it_should_behave_like "when calling attr_array"
  
  it "should not create an accessor method for the array" do
    @target.should_not respond_to(:elements)
  end
end

describe Class do

  it "when calling class_attr_accessor should add class attribute accessors for each symbol passed" do
    class Foo; end
    Foo.class_attr_accessor(:bar)
    Foo.should respond_to(:bar)
    Foo.should respond_to(:bar=)
  end

  it "when calling class_attr_reader should add class attribute readers for each symbol passed" do
    class Bar; end
    Bar.class_attr_reader(:foo)
    Bar.should respond_to(:foo)
    Bar.should_not respond_to(:foo=)
  end

  it "when calling class_attr_writer should add class attribute readers for each symbol passed" do
    class FooBar; end
    FooBar.class_attr_writer(:bar)
    FooBar.should_not respond_to(:bar)
    FooBar.should respond_to(:bar=)
  end

  it "when calling instance_attr_accessor should add instance attribute accessors for each symbol passed" do
    class Snafu; end
    Snafu.instance_attr_accessor(:bar)
    instance = Snafu.new
    instance.should respond_to(:bar)
    instance.should respond_to(:bar=)
  end
end