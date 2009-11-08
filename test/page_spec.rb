require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require_fixtures 'application_spec_applications'

describe Trellis::Page, " when sending an event to a page" do
  before(:each) do
    @application = TestApp::MyApp.new
    @request = Rack::MockRequest.new(@application) 
  end
  
  it "should redirect to the receiving page if the event handler returns self" do
    response = @request.get("/home/events/event1")
    response.status.should be(302)
    response.headers['Location'].should == '/home'
  end
  
  it "should return a response as a string if the event handler returns a String" do
    response = @request.get("/home/events/event2")
    response.body.should == "just some text"
  end  
  
  it "should redirect to the injected page as a response if the event handler returns an injected page" do
    response = @request.get("/home/events/event3")
    response.status.should be(302)
    response.headers['Location'].should == '/other'
  end

  it "should be able to pass a value as the last element or the URL" do
    response = @request.get("/home/events/event4/quo%20vadis")
    response.body.should == "the value is quo vadis"
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

describe Trellis::Page, " when given a template" do
  before(:each) do
    @application = TestApp::MyApp.new
    @request = Rack::MockRequest.new(@application)
  end

  it "should rendered it correctly if it is in HAML format" do
    response = @request.get("/haml_page")
    response.body.should == "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n<html xmlns=\"http://www.w3.org/1999/xhtml\">\n  <head>\n    <meta content=\"text/html; charset=UTF-8\" http-equiv=\"Content-Type\" />\n    <title>\n      This is a HAML page\n    </title>\n  </head>\n  <body>\n    <h1>\n      Page Title\n    </h1>\n    <p>\n      HAML rocks!\n    </p>\n  </body>\n</html>\n"
  end

  it "should rendered it correctly if it is in Textile format" do
    response = @request.get("/textile_page")
    response.body.should == "<p>A <strong>simple</strong> example.</p>"
  end

  it "should rendered it correctly if it is in Markdown format" do
    response = @request.get("/mark_down_page")
    response.body.should == "<html><body><h1>This is the Title</h1>\n\n<h2>This is the SubTitle</h2>\n\n<p>This is some text</p></body></html>"
  end
  
  it "should rendered it correctly if it is in ERuby format" do
    response = @request.get("/e_ruby_page")
    response.body.should == "<html><body><ul><li>Hey</li><li>bud</li><li>let's</li><li>party!</li></ul></body></html>"
  end  

  it "should rendered it correctly if it is in HTML format" do
    response = @request.get("/html_page")
    response.body.should == "<html><body><h1>This is just HTML</h1></body></html>"
  end
end

