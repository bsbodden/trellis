require File.dirname(__FILE__) + '/spec_helper.rb'

describe Trellis::DefaultRouter, " when processing a request" do
  before do
    @regexp = Trellis::DefaultRouter::ROUTE_REGEX
  end
  
  it "should extract the page " do
    value, source, event, destination = "/some_page".match(@regexp).to_a.reverse
    value.should be_nil
    source.should be_nil
    event.should be_nil
    destination.should_not be_nil
    destination.should == "some_page"
  end
  
  it "should extract the page and event " do
    value, source, event, destination = "/some_page.event".match(@regexp).to_a.reverse
    value.should be_nil
    source.should be_nil
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end  
  
  it "should extract the page, event and source " do
    value, source, event, destination = "/some_page.event_source".match(@regexp).to_a.reverse
    value.should be_nil
    source.should == "source"
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end  
  
  it "should extract the page, event and source and value" do
    value, source, event, destination = "/some_page.event_source/123".match(@regexp).to_a.reverse
    value.should == "123"
    source.should == "source"
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end  

  it "should extract the page, event and value" do
    value, source, event, destination = "/some_page.event/123".match(@regexp).to_a.reverse
    value.should == "123"
    source.should be_nil
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end   
end
