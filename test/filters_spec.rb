require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack" 
require "rack/test"
require_fixtures 'filters_fixtures'

describe Trellis::Page, " with applied filters " do
  include Rack::Test::Methods
  
  before do
    @app = FiltersApp::FiltersApp.new
  end

  def app
    @app
  end
  
  it "should be redirected by an around filter to a specific destination" do
    get "/protected_one"
    redirect = last_response.headers['Location']
    redirect.should == '/not_authorized'
  end
  
  it "should be allowed to render by an around filter" do
    @app.allow = true
    get "/protected_one"
    last_response.body.should == %[<?xml version=\"1.0\"?>\n<p>protected one</p>\n]
  end
  
  it "should be redirected by an around filter to a specific destination when using the get method" do
    get "/protected_two"
    redirect = last_response.headers['Location']
    redirect.should == '/not_authorized'
  end
  
  it "should be allowed to process the get method by an around filter" do
    @app.allow = true
    get "/protected_two"
    last_response.body.should == %[<?xml version=\"1.0\"?>\n<p>protected two</p>\n]
  end
  
  it "should apply filters only to the specified methods" do
    get "/protected_three"
    last_response.body.should == %[<?xml version=\"1.0\"?>\n<p>blah</p>\n]
    get "/protected_three/events/knock_knock"
    redirect = last_response.headers['Location']
    redirect.should == '/not_authorized'
  end
  
  it "should allow to daisy chain filters" do
    @app.allow = true
    env = Hash.new
    env["rack.session"] = Hash.new
    get "/protected_three/events/knock_knock", {}, env
    redirect = last_response.headers['Location']
    redirect.should eql('/protected_three')
    get redirect, {}, env
    last_response.body.should include("<?xml version=\"1.0\"?>\n<p>?ereht s'ohw</p>\n")
  end

end