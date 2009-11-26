require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack"
require_fixtures 'application_spec_applications'

describe Trellis::Renderer do

  it "should render a given page template" do
    page = TestApp::Home.new
    renderer = Trellis::Renderer.new(page)
    result = renderer.render
    result.should == "<html><body><h1>Hello World!</h1></body></html>"
  end

  it "should have access to page instance variables" do
    page = TestApp::SamplePage.new
    page.value = "chunky bacon"
    renderer = Trellis::Renderer.new(page)
    result = renderer.render
    result.should == "#{THTML_TAG}<body>chunky bacon</body></html>"
  end

  it "should have access to the page name" do
    page = TestApp::AnotherSamplePage.new
    renderer = Trellis::Renderer.new(page)
    result = renderer.render
    result.should == "#{THTML_TAG}<body>TestApp::AnotherSamplePage</body></html>"
  end

end

