require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require "rack/test"
require_fixtures 'application_spec_applications'

describe Trellis::Page, " when sending an event to a page" do
  include Rack::Test::Methods

  def app
    TestApp::MyApp.new
  end
  
  it "should redirect to the receiving page if the event handler returns self" do
    get "/home/events/event1"
    redirect = last_response.headers['Location']
    redirect.should eql('/home')
  end
  
  it "should return a response as a string if the event handler returns a String" do
    get "/home/events/event2"
    last_response.body.should == "just some text"
  end  
  
  it "should redirect to the injected page as a response if the event handler returns an injected page" do
    get "/home/events/event3" 
    redirect = last_response.headers['Location']
    redirect.should eql('/other')
  end

  it "should be able to pass a value as the last element or the URL" do
    get "/home/events/event4/quo%20vadis" 
    last_response.body.should == "the value is quo vadis"
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

describe Trellis::Page, " when provided with a #get method" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end

  it "should redirect to the page returned" do
    get "/page_with_get_redirect" 
    redirect = last_response.headers['Location']
    redirect.should eql('/other')
  end
  
  it "should return a response as a string if the ==get== methood returns a String" do
    get "/page_with_get_plain_text"
    last_response.body.should == "some content"
  end
  
  it "should render the result of the ==get== method if it is the same page" do
    get "/page_with_get_same" 
    last_response.body.should include("<p>Vera, what has become of you?</p>")
  end
end

describe Trellis::Page, " when given a template" do
  include Rack::Test::Methods
  
  def app
    TestApp::MyApp.new
  end

  it "should rendered it correctly if it is in HAML format" do
    get "/haml_page" 
    last_response.body.should include(%[<title>\n      This is a HAML page\n    </title>\n  </head>\n  <body>\n    <h1>\n      Page Title\n    </h1>\n    <p>\n      HAML rocks!\n    </p>])
  end

  it "should rendered it correctly if it is in Textile format" do
    get "/textile_page"
    last_response.body.should == "<?xml version=\"1.0\"?>\n<p>A <strong>simple</strong> example.</p>\n"
  end

  it "should rendered it correctly if it is in Markdown format" do
    get "/mark_down_page"
    last_response.body.should include(%[body><h1>This is the Title</h1>\n\n<h2>This is the SubTitle</h2>\n\n<p><strong>This is some text</strong>])
  end
  
  it "should rendered it correctly if it is in ERuby format" do
    get "/e_ruby_page" 
    last_response.body.should include("<li>Hey</li>")
    last_response.body.should include("<li>bud</li>")
    last_response.body.should include("<li>let's</li>")
    last_response.body.should include("<li>party!</li>")
  end  

  it "should rendered it correctly if it is in HTML format" do
    get "/html_page"
    last_response.body.should include("<h1>This is just HTML</h1>")
  end
end

describe Trellis::Page do
  include Rack::Test::Methods
  
  before do
    @application = TestApp::MyApp.new
  end
  
  def app
    @application
  end
  
  it "should have access to application constants in ERuby format" do
    get "/constant_access_page"
    last_response.body.should include("<p>it's just us, chickens!</p>")
  end 
  
  it "should have access to application methods in ERuby format" do
    get "/method_access_page" 
    last_response.body.should include("<p>helloooo, la la la</p>")
  end
  
  it "should invoke the before_load method if provided by the page" do
    get "/before_load" 
    last_response.body.should include("8675309")
  end
  
  it "should invoke the after_load method if provided by the page" do
    get "/after_load" 
    last_response.body.should include("chunky bacon!")  
  end
  
  it "should invoke the before_render method if provided by the page" do
    get "/before_render" 
    last_response.body.should include("8675309")
  end
  
  it "should invoke the after_render method if provided by the page" do
    env = Hash.new
    env["rack.session"] = Hash.new
    get "/after_render", {}, env
    env["rack.session"][:my_field].should include("changed in after_render method")  
  end
  
  it "should redirect if giving an explicit redirect" do
    get '/explicit_redirect'
    redirect = last_response.headers['Location']
    redirect.should eql('/hello/Ford%20Prefect')
    get redirect
    last_response.body.should include("<h2>Hello</h2>\n    \n    Ford%20Prefect")
  end
end

