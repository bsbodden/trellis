require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require_fixtures 'application_spec_applications'

describe Trellis::Application, " when declared" do
  before do
    @homepage = TestApp::MyApp.instance_eval { @homepage }
    @pages = TestApp::MyApp.instance_eval { @pages }
    @static_routes = TestApp::MyApp.instance_eval { @static_routes }
  end
  
  it "should contain a contain the symbol for its home page" do
    @homepage.should == :home
  end
  
  it "should contain any declared static routes" do
    images_route = @static_routes.select { |item| item[:urls].include?('/images') }
    images_route.should_not be_empty  
    style_route = @static_routes.select { |item| item[:urls].include?('/style') }
    style_route.should_not be_empty  
    favicon_route = @static_routes.select { |item| item[:urls].include?('/favicon.ico') }
    favicon_route.should_not be_empty
    jquery_route = @static_routes.select { |item| item[:urls].include?('/jquery') && item[:root].include?('./js') }
    jquery_route.should_not be_empty
  end

  it "should include Rack::Utils" do
    TestApp::MyApp.included_modules.should include(Rack::Utils)
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

describe Trellis::Application, " requesting a route" do
  before(:each) do
    application = TestApp::MyApp.new
    @request = Rack::MockRequest.new(application)
  end

  it "should return a 404 (not found)" do
    response = @request.get("/blowup")
    response.status.should be(404)
  end

  it "should return the page contents of the first page matching the route" do
    response = @request.get("/whoa")
    response.body.should == "<html><body>whoa!</body></html>"
  end

  it "should support a single named parameter" do
    response_brian = @request.get("/hello/brian")
    response_anne = @request.get("/hello/anne")
    response_brian.body.should == "<html><body><h2>Hello</h2>brian</body></html>"
    response_anne.body.should == '<html><body><h2>Hello</h2>anne</body></html>'
  end

  it "should support multiple named parameters" do
    response = @request.get('/report/2009/05/31')
    response.body.should == "<html><body><h2>Report for</h2>05/31/2009</body></html>"
  end
end