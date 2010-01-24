require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require 'rack/test'
require_fixtures 'application_fixtures'

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
    last_response.body.should == %[<?xml version=\"1.0\"?>\n<html>\n  <body>\n    <h1>Hello World!</h1>\n  </body>\n</html>\n]
  end
end

describe Trellis::Application, " requesting a route" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end

  it "should return a 404 (not found) for an unmatch request" do
    get "/blowup"
    last_response.status.should be(404)
  end

  it "should return the page contents of the first page matching the route" do
    get "/whoa"
    last_response.body.should == "<?xml version=\"1.0\"?>\n<html>\n  <body>whoa!</body>\n</html>\n"
  end

  it "should support a single named parameter" do
    get "/hello/brian"
    last_response.body.should include("<body>\n    <h2>Hello</h2>\n    \n    brian\n  </body>")
    get "/hello/anne"
    last_response.body.should include("<body>\n    <h2>Hello</h2>\n    \n    anne\n  </body>")
  end

  it "should support multiple named parameters" do
    get '/report/2009/05/31'
    last_response.body.should include("<body><h2>Report for</h2>05/31/2009</body>")
  end

  it "should support optional parameters" do
    get '/foobar/hello/world'
    last_response.body.should include("<body>hello-world</body>")
    get '/foobar/hello'
    last_response.body.should include("<body>hello-</body>")
    get '/foobar'
    last_response.body.should include("<body>-</body>")
  end

  it "should support a wildcard parameters" do
    get '/splat/goodbye/cruel/world'
    last_response.body.should include("goodbye/cruel/world")
  end

  it "should supports mixing multiple splats" do
    get '/splats/bar/foo/bling/baz/boom'
    last_response.body.should include("barblingbaz/boom")

    get '/splats/bar/foo/baz'
    last_response.status.should be(404)
  end

  it "should supports mixing named and wildcard params" do
    get '/mixed/afoo/bar/baz'
    last_response.body.should include("bar/baz-afoo")
  end

  it "should merge named params and query string params" do
    get "/hello/Bean?salutation=Mr.%20"
    last_response.body.should include("<h2>Hello</h2>\n    Mr. \n    Bean")
  end

  it "should match a dot ('.') as part of a named param" do
    get "/foobar/user@example.com/thebar"
    last_response.body.should include("user@example.com-thebar")
  end

  it "should match a literal dot ('.') outside of named params" do
    get "/downloads/logo.gif"
    last_response.body.should include("logo-gif")
  end
  
  it "should redirect to a custom route when handling an event returning a custom routed page" do
    post "/admin/login/events/submit.login"
    redirect = last_response.headers['Location']
    redirect.should eql('/admin/result')
    get redirect
    last_response.body.should include('<h1>PostRedirectPage</h1>')
  end
  
end

describe Trellis::Application do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should have access to any persistent fields" do
    get "/application_data_page"
    last_response.body.should == "<?xml version=\"1.0\"?>\n<html>\n  <body>\n    <p></p>\n  </body>\n</html>\n"
  end
  
  it "should be able to modify any persistent fields" do
    env = Hash.new
    env["rack.session"] = Hash.new
    get "/application_data_page/events/save", {}, env
    redirect = last_response.headers['Location']
    redirect.should eql('/application_data_page')
    get redirect, {}, env
    last_response.body.should == "<?xml version=\"1.0\"?>\n<html>\n  <body>\n    <p>here's a value</p>\n  </body>\n</html>\n"
  end
  
  it "should have access to any application public methods" do
    get "/application_method_page"
    last_response.body.should == "<?xml version=\"1.0\"?>\n<html>\n  <body>\n    <p>Zaphod Beeblebrox</p>\n  </body>\n</html>\n"
  end

end

describe Trellis::Application, " with declared partial views" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should render a view defined in markaby" do
    get "/partial_markaby"
    last_response.body.should  include("<p>This content was generated by Markaby</p>")
  end
  
  it "should render a view defined in haml" do
    get "/partial_haml"
    last_response.body.should include("<p>This content was generated by HAML</p>")
  end
  
  it "should render a view defined in textile" do
    get "/partial_textile"
    last_response.body.should include("<p>This content was generated by <strong>Textile</strong></p>")
  end
  
  it "should render a view defined in markdown" do
    get "/partial_markdown"
    last_response.body.should include("<h1>This content was generated by Markdown</h1>")
  end
  
  it "should render a view defined in eruby" do
    get "/partial_eruby"
    last_response.body.should include("<p>This content was generated by The Amazing ERubis</p>")
  end
  
  it "should render a view defined in eruby and have access to the surrounding context" do
    get "/partial_eruby_loop"
    last_response.body.join.should include("<ul> <li>ichi</li> <li>ni</li> <li>san</li> <li>shi</li> <li>go</li> <li>rokku</li> <li>hichi</li> <li>hachi</li> <li>kyu</li> <li>jyu</li> </ul>")
  end

end

describe Trellis::Application, " with declared layout" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end
  
  it "should render a page with its corresponding layout" do
    get "/with_layout_static"
    last_response.body.should include("<p>\n<h3>Hello Arizona!</h3></p>")
  end
  
  it "should render a page with its corresponding layout" do
    get "/with_layout_variable"
    last_response.body.should include("p>\n<h3>Hello Arizona!</h3></p>")
  end
  
  it "should render any embedded trellis components" do
    get "/markaby_template_with_components"
    last_response.body.should include("<p>Vulgar Vogons</p>")
  end
  
  it "should render and eruby template and layout" do
    get '/eruby_template_and_layout'
    last_response.body.join.should include("<ul> <li>one</li> <li>two</li> <li>tres</li> <li>cuatro</li> </ul>")
  end
end
