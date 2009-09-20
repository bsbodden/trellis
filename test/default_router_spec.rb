require File.dirname(__FILE__) + '/spec_helper.rb'

describe Trellis::DefaultRouter, " when processing a request" do
  before do
    @regexp = Trellis::DefaultRouter::ROUTE_REGEX
    @router = Trellis::DefaultRouter.new
  end

  it "should extract the page" do
    value, source, event, destination = "/some_page".match(@regexp).to_a.reverse
    value.should be_nil
    source.should be_nil
    event.should be_nil
    destination.should_not be_nil
    destination.should == "some_page"
  end

  it "should extract the page and event" do
    value, source, event, destination = "/some_page/events/event".match(@regexp).to_a.reverse
    value.should be_nil
    source.should be_nil
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end

  it "should extract the page, event and source" do
    value, source, event, destination = "/some_page/events/event.source".match(@regexp).to_a.reverse
    value.should be_nil
    source.should == "source"
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end

  it "should extract the page, event and source and value" do
    value, source, event, destination = "/some_page/events/event.source/123".match(@regexp).to_a.reverse
    value.should == "123"
    source.should == "source"
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end

  it "should extract the page, event and value" do
    value, source, event, destination = "/some_page/events/event/123".match(@regexp).to_a.reverse
    value.should == "123"
    source.should be_nil
    event.should == "event"
    destination.should_not be_nil
    destination.should == "some_page"
  end

  it "should build a path given page" do
    page = TestApp::Home.new
    path = Trellis::DefaultRouter.to_uri(:page => page)
    path.should == "/home"
  end

  it "should build a path given page and an event" do
    page = TestApp::Home.new
    path = Trellis::DefaultRouter.to_uri(:page => page, :event => 'event')
    path.should == "/home/events/event"
  end

  it "should build a path given page, an event and a source" do
    page = TestApp::Home.new
    path = Trellis::DefaultRouter.to_uri(:page => page, :event => 'event', :source => 'source')
    path.should == "/home/events/event.source"
  end

  it "should build a path given page, an event, a source and a value" do
    page = TestApp::Home.new
    path = Trellis::DefaultRouter.to_uri(:page => page, :event => 'event', :source => 'source', :value => 'value')
    path.should == "/home/events/event.source/value"
  end

  it "should match valid patterns" do
    page_request = mock('request', :path_info => '/page')
    page_event_request = mock('request', :path_info => '/page/events/event')
    page_event_source_request = mock('request', :path_info => '/page/events/event.source')
    page_event_value_request = mock('request', :path_info => '/page/events/event/value')
    page_event_source_value_request = mock('request', :path_info => '/page/events/event.source/value')

    @router.matches?(page_request).should be_true
    @router.matches?(page_event_request).should be_true
    @router.matches?(page_event_source_request).should be_true
    @router.matches?(page_event_value_request).should be_true
    @router.matches?(page_event_source_value_request).should be_true
  end
end
