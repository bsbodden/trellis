require 'rubygems'
require 'spec'
require 'rack'
require 'rack/test'
require File.dirname(__FILE__) + '/../flickr.rb'

describe Flickr::FlickrApp do
  include Rack::Test::Methods

  def app
    Flickr::FlickrApp.new
  end
  
  it "should have a home page declared" do
    Flickr::FlickrApp.homepage.should == :home
  end
  
  it "should return an OK HTTP status" do
    get "/"
    last_response.status.should be(200)
  end
  
  it "should render the flickr component" do
    get '/'
    last_response.body.should include(%[<div id="flickr_viewer">])
  end
  
  it "should render the default number of images in the default format" do
    get '/'
    body = Nokogiri::HTML(last_response.body)
    images = body.xpath("//div[@id='test1']//div[@id='flickr_image']/img")
    
    images.should have(3).images
    images.each { |image| image['src'].should match(/\Ahttp.*_s.jpg\Z/) }
  end
  
  it "should render a requested number of images in the requested format" do
    get '/'
    body = Nokogiri::HTML(last_response.body)
    images = body.xpath("//div[@id='test2']//div[@id='flickr_image']/img")
    
    images.should have(2).images
    images.each { |image| image['src'].should match(/\Ahttp.*_t.jpg\Z/) }
  end
  
end
