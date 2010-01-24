require File.dirname(__FILE__) + '/spec_helper.rb'

require_fixtures 'application_fixtures'

describe Trellis::Router, " when constructed" do

  it "with a page parameter should route to that page " do
    @router = Trellis::Router.new(:page => TestApp::Home)
    @router.route().destination.should == TestApp::Home
  end

  it "with a simple path it should match that path" do
    request = mock('request', :path_info => '/hello')
    @router = Trellis::Router.new(:path => '/hello')
    @router.matches?(request).should be_true
  end

  it "with a path containing a single named parameter should match valid variations of that path" do
    request_brian = mock('request', :path_info => '/hello/brian')
    request_michael = mock('request', :path_info => '/hello/michael')
    @router = Trellis::Router.new(:path => '/hello/:name')
    @router.matches?(request_brian).should be_true
    @router.matches?(request_michael).should be_true
  end

  it "with a path containing multiple named parameters should match valid variations of that path" do
    request_xmas = mock('request', :path_info => '/hello/2009/12/25')
    request_labor_day = mock('request', :path_info => '/hello/2009/09/07')
    @router = Trellis::Router.new(:path => '/hello/:year/:month/:day')
    @router.matches?(request_xmas).should be_true
    @router.matches?(request_labor_day).should be_true
  end

  it "with a path containing a single named parameters should collect the parameter" do
    @router = Trellis::Router.new(:path => '/hello/:name')
    @router.keys.should include('name')
  end

  it "with a path containing multiple parameters should collect all parameters" do
    @router = Trellis::Router.new(:path => '/hello/:year/:month/:day')
    @router.keys.should include('year', 'month', 'day')
  end

  it "with a path containing multiple optional parameters should collect all parameters" do
    @router = Trellis::Router.new(:path => '/?:foo?/?:bar?')
    @router.keys.should include('foo', 'bar')
  end

  it "with a path containing a single wildcard param it should capture the values in splat" do
    @router = Trellis::Router.new(:path => '/*')
    @router.keys.should include('splat')
  end
  
  it "should be able to be sorted by 'matchability'" do
    route_1 = Trellis::Router.new(:path => '/hello/:one/:two') 
    route_2 = Trellis::Router.new(:path => '/hello/jim/:last')
    route_3 = Trellis::Router.new(:path => '/hello/*')
    route_4 = Trellis::Router.new(:path => '/hello/*/:foo/*')
    
    routes = [ route_1, route_2, route_3, route_4 ].sort {|a,b| b.score <=> a.score }
    
    routes[0].should be(route_4)
    routes[1].should be(route_2)
    routes[2].should be(route_1)
    routes[3].should be(route_3)
  end
  
  it "a catch all route should always be last when sorted with other routes" do
    route_1 = Trellis::Router.new(:path => '/admin/login')
    route_2 = Trellis::Router.new(:path => '/*')
    route_3 = Trellis::Router.new(:path => '/admin/pages')
    route_4 = Trellis::Router.new(:path => '/admin/new/page')
    route_5 = Trellis::Router.new(:path => '/admin/page/:id')
    route_6 = Trellis::Router.new(:path => '/admin/page/:id/delete')
    
    routes = [ route_1, route_2, route_3, route_4, route_5, route_6 ].sort {|a,b| b.score <=> a.score }
    
    routes[0].should be(route_6)
    routes[1].should be(route_4)
    routes[2].should be(route_5)
    routes[3].should be(route_3)
    routes[4].should be(route_1)
    routes[5].should be(route_2)    
  end
 
end
