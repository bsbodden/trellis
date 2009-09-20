require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack"
require 'rack/test'
require_fixtures 'component_spec_components'

describe Trellis::Component, " in an application" do
  include Rack::Test::Methods

  def app
    TestComponents::ApplicationWithComponents.new
  end

  it "should return its intended content" do
    get '/'
    last_response.body.should eql('<html><body>hello from simple component</body></html>')
  end

  it "should render each instance of a component in the template" do
    get '/counters'
    counter_one_markup = %[<div id="one">0<a href="/page_with_stateful_component/events/add.counter_one">++</a><a href="/page_with_stateful_component/events/subtract.counter_one">--</a></div>]
    counter_two_markup = %[<div id="two">0<a href="/page_with_stateful_component/events/add.counter_two">++</a><a href="/page_with_stateful_component/events/subtract.counter_two">--</a></div>]
    counter_three_markup = %[<div id="three">0<a href="/page_with_stateful_component/events/add.counter_three">++</a><a href="/page_with_stateful_component/events/subtract.counter_three">--</a></div]
    last_response.body.should include(counter_one_markup)
    last_response.body.should include(counter_two_markup)
    last_response.body.should include(counter_three_markup)
  end

  it "should provide an instance of each component in the template to the page" do
    counters_page = TestComponents::PageWithStatefulComponent.new
    counter_one = counters_page.instance_eval { @counter_one }
    counter_two = counters_page.instance_eval { @counter_two }
    counter_three = counters_page.instance_eval { @counter_three }
    counter_one.should be_an_instance_of(TestComponents::Counter)
    counter_two.should be_an_instance_of(TestComponents::Counter)
    counter_three.should be_an_instance_of(TestComponents::Counter)
  end

  it "should provide a logger" do
    counters_page = TestComponents::PageWithStatefulComponent.new
    counter_one = counters_page.instance_eval { @counter_one }
    counter_one.should respond_to(:logger)
  end

  it "should respond to an event for which it provides an event handler" do
    env = Hash.new
    env["rack.session"] = Hash.new

    get '/page_with_stateful_component/events/add.counter_one', {}, env

    redirect = last_response.headers['Location']

    redirect.should eql('/page_with_stateful_component')

    get redirect, {}, env
    
    counter_one_markup = %[<div id="one">1]
    counter_two_markup = %[<div id="two">0]
    counter_three_markup = %[<div id="three">0]

    last_response.body.should include(counter_one_markup)
    last_response.body.should include(counter_two_markup)
    last_response.body.should include(counter_three_markup)
  end

  it "should be able to provide a style link contribution to the page" do
    get '/page_with_contributions'
    last_response.body.should include('<link href="/someplace/my_styles.css" rel="stylesheet" type="text/css" />')
  end

  it "should be able to provide a script link contribution to the page" do
    get '/page_with_contributions'
    last_response.body.should include('<script src="/someplace/my_script.js" type="text/javascript"></script>')
  end

  it "should be able to provide a style contribution to the page" do
    get '/page_with_contributions'
    last_response.body.should include('<style type="text/css">html { color:#555555; background-color:#303030; }</style>')
  end

  it "should be able to provide a style contribution to the page per instance" do
    get '/page_with_contributions'
    last_response.body.scan(%[<style type=\"text/css\">/* just a comment */</style>]).should have_exactly(2).matches
  end

  it "should be able to provide a script contribution per instance and access instance information" do
    get '/page_with_contributions'
    last_response.body.should include(%[<script type="text/javascript">alert('hello from one');</script>])
    last_response.body.should include(%[<script type="text/javascript">alert('hello from two');</script>])
  end

  it "should be able to provide a script contribution per class" do
    get '/page_with_contributions'
    last_response.body.should include(%[alert('hello just once');])
  end

  it "should be able to provide a dom modification block" do
    get '/page_with_contributions'
    last_response.body.scan(%[<body class=\"new_class\">]).should have_exactly(1).match
  end

end
