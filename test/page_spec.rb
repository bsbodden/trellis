require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require_fixtures 'application_spec_applications'

describe Trellis::Page, " when sending an event to a page" do
  before(:each) do
    @application = TestApp::MyApp.new
    @request = Rack::MockRequest.new(@application) 
  end
  
  it "should render the receiving page if the event handler returns self" do
    response = @request.get("/home.event1")
    response.body.should == "<html><body><h1>Hello World!</h1></body></html>"
  end
  
  it "should return a response as a string if the event handler returns a String" do
    response = @request.get("/home.event2")
    response.body.should == "just some text"
  end  
  
  it "should render the injected page as a response if the event handler returns an injected page " do
    response = @request.get("/home.event3")
    response.body.should == "<html><body><p>Goodbye Cruel World </p></body></html>"
  end
  
  it "should invoke the before_load method if provided by the page" do
    response = @request.get("/before_load")
    response.body.should == "<html><body>8675309</body></html>"
  end
  
  it "should invoke the after_load method if provided by the page" do
    response = @request.get("/after_load")
    response.body.should == "<html><body>chunky bacon!</body></html>"    
  end
end

describe Trellis::Page, " when calling inject_dependent_pages on an instance of Page" do
  it "should contain instances of the injected pages" do
    homepage = TestApp::Home.new
    homepage.inject_dependent_pages
    injected_page = homepage.instance_eval { @other }
    injected_page.should be_an_instance_of(TestApp::Other)
  end
end

describe Trellis::Page, " when created with a custom route" do
  it "should contain an instance of Router" do
    router = TestApp::RoutedDifferently.router
    router.should_not be_nil
    router.should be_an_instance_of(Trellis::Router)
  end
end

