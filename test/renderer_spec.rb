require File.dirname(__FILE__) + '/spec_helper.rb'

require "rack"
require_fixtures 'application_fixtures'

describe Trellis::Renderer do

  it "should render a given page template" do
    page = TestApp::Home.new
    renderer = Trellis::Renderer.new(page)
    result = renderer.render
    result.should == "<?xml version=\"1.0\"?>\n<html>\n  <body>\n    <h1>Hello World!</h1>\n  </body>\n</html>\n"
  end

  it "should have access to page instance variables" do
    page = TestApp::SamplePage.new
    page.value = "chunky bacon"
    renderer = Trellis::Renderer.new(page)
    result = renderer.render
    result.should include("<body>\n    chunky bacon\n  </body>")
  end

  it "should have access to the page name" do
    page = TestApp::AnotherSamplePage.new
    renderer = Trellis::Renderer.new(page)
    result = renderer.render
    result.should include("<body>\n    TestApp::AnotherSamplePage\n  </body>")
  end

end

