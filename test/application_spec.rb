require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require 'rack/test'
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
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should return an OK HTTP status" do
    get "/"
    last_response.status.should be(200)
  end

  it "should reply with the home page" do
    get "/"
    last_response.body.should == "<html><body><h1>Hello World!</h1></body></html>"
  end
end

describe Trellis::Application, " requesting a route" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end

  it "should return a 404 (not found)" do
    get "/blowup"
    last_response.status.should be(404)
  end

  it "should return the page contents of the first page matching the route" do
    get "/whoa"
    last_response.body.should == "<html><body>whoa!</body></html>"
  end

  it "should support a single named parameter" do
    get "/hello/brian"
    last_response.body.should == "#{THTML_TAG}<body><h2>Hello</h2>brian</body></html>"
    get "/hello/anne"
    last_response.body.should == "#{THTML_TAG}<body><h2>Hello</h2>anne</body></html>"
  end

  it "should support multiple named parameters" do
    get '/report/2009/05/31'
    last_response.body.should == "#{THTML_TAG}<body><h2>Report for</h2>05/31/2009</body></html>"
  end

  it "should support optional parameters" do
    get '/foobar/hello/world'
    last_response.body.should == "#{THTML_TAG}<body>hello-world</body></html>"
    get '/foobar/hello'
    last_response.body.should == "#{THTML_TAG}<body>hello-</body></html>"
    get '/foobar'
    last_response.body.should == "#{THTML_TAG}<body>-</body></html>"
  end

  it "should support a wildcard parameters" do
    get '/splat/goodbye/cruel/world'
    last_response.body.should == "#{THTML_TAG}<body>goodbye/cruel/world</body></html>"
  end

  it "should supports mixing multiple splats" do
    get '/splats/bar/foo/bling/baz/boom'
    last_response.body.should == "#{THTML_TAG}<body>barblingbaz/boom</body></html>"

    get '/splats/bar/foo/baz'
    last_response.status.should be(404)
  end

  it "should supports mixing named and wildcard params" do
    get '/mixed/afoo/bar/baz'
    last_response.body.should == "#{THTML_TAG}<body>bar/baz-afoo</body></html>"
  end

  it "should merge named params and query string params" do
    get "/hello/Bean?salutation=Mr.%20"
    last_response.body.should == "#{THTML_TAG}<body><h2>Hello</h2>Mr. Bean</body></html>"
  end

  it "should match a dot ('.') as part of a named param" do
    get "/foobar/user@example.com/thebar"
    last_response.body.should == "#{THTML_TAG}<body>user@example.com-thebar</body></html>"
  end

  it "should match a literal dot ('.') outside of named params" do
    get "/downloads/logo.gif"
    last_response.body.should == "#{THTML_TAG}<body>logo-gif</body></html>"
  end
end

describe Trellis::Application do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should have access to any persistent fields" do
    get "/application_data_page"
    last_response.body.should == "<html><body><p></p></body></html>"
  end
  
  it "should be able to modify any persistent fields" do
    env = Hash.new
    env["rack.session"] = Hash.new
    get "/application_data_page/events/save", {}, env
    redirect = last_response.headers['Location']
    redirect.should eql('/application_data_page')
    get redirect, {}, env
    last_response.body.should == "<html><body><p>here's a value</p></body></html>"
  end
  
  it "should have access to any application public methods" do
    get "/application_method_page"
    last_response.body.should == "<html><body><p>Zaphod Beeblebrox</p></body></html>"
  end

end

describe Trellis::Application, " with declared partial views" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should render a view defined in markaby" do
    get "/partial_markaby"
    last_response.body.should == "<html><body><p>This content was generated by Markaby</p></body></html>"
  end
  
  it "should render a view defined in haml" do
    get "/partial_haml"
    last_response.body.should == "<html><body><p>This content was generated by HAML</p>\n</body></html>"
  end
  
  it "should render a view defined in textile" do
    get "/partial_textile"
    last_response.body.should == "<html><body><p>This content was generated by <strong>Textile</strong></p></body></html>"
  end
  
  it "should render a view defined in markdown" do
    get "/partial_markdown"
    last_response.body.should == "<html><body><html><body><h1>This content was generated by Markdown</h1></body></html></body></html>"
  end
  
  it "should render a view defined in eruby" do
    get "/partial_eruby"
    last_response.body.should == "<html><body><p>This content was generated by The Amazing ERubis</p></body></html>"
  end
  
  it "should render a view defined in eruby and have access to the surrounding context" do
    get "/partial_eruby_loop"
    last_response.body.should == "<html><body><ul><li>ichi</li><li>ni</li><li>san</li><li>shi</li><li>go</li><li>rokku</li><li>hichi</li><li>hachi</li><li>kyu</li><li>jyu</li></ul></body></html>"
  end

end

describe Trellis::Application, " with declared layout" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should render a page with its corresponding layout" do
    get "/with_layout_static"
    last_response.body.should == "<html><body><p><h3>Hello Arizona!</h3></p></body></html>"
  end
  
  it "should render a page with its corresponding layout" do
    get "/with_layout_variable"
    last_response.body.should == "<html><body><p><h3>Hello Arizona!</h3></p></body></html>"
  end
end
