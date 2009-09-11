require File.dirname(__FILE__) + '/spec_helper.rb'

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
    
end
