require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require_fixtures 'application_spec_applications'

describe Trellis::Application, " a Trellis application when declared" do
  before do
    @homepage = TestApp::MyApp.instance_eval { @homepage }
    @pages = TestApp::MyApp.instance_eval { @pages }
    @static_routes = TestApp::MyApp.instance_eval { @static_routes }
  end
  
  it "should contain a contain the symbol for its home page" do
    @homepage.should == :home
  end
  
  it "should contain the home page in its collection of pages" do
    @pages.include?(:home).should be(true)
  end
  
  it "should contain any declared static routes" do
    images_route = @static_routes.select { |item| item[:urls].include?('/images') }
    images_route.should_not be_empty    
    style_route = @static_routes.select { |item| item[:urls].include?('/style') }
    style_route.should_not be_empty  
    favicon_route = @static_routes.select { |item| item[:urls].include?('/favicon.ico') }
    favicon_route.should_not be_empty
    yui_route = @static_routes.select { |item| item[:urls].include?('/yui') && item[:root].include?('./js') }
    yui_route.should_not be_empty    
  end
 
end

describe Trellis::Application, " when requesting the root url with a GET" do
  before(:each) do
    application = TestApp::MyApp.new
    request = Rack::MockRequest.new(application) 
    @response = request.get("/")
  end
  
  it "should return an OK HTTP status" do
    @response.status.should be(200)
  end

  it "should reply with the home page" do
    @response.body.should == "<html><body><h1>Hello World!</h1></body></html>"
  end
end

describe Trellis::Application, " when sending an event to a page" do
  before(:each) do
    application = TestApp::MyApp.new
    @request = Rack::MockRequest.new(application) 
  end
  
  it "if the event handler returns self it should render the receiving page" do
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
end