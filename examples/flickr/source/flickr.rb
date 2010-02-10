require 'rubygems'
require 'trellis'
require 'xmlrpc/client'
require 'nokogiri'
require 'builder'

include Trellis

module Flickr
  
  # This component grabs a set of random images from Flickr using the 
  # interestingness web services (using XML-RCP)
  # 
  # s	small square 75x75
  # t	thumbnail, 100 on longest side
  # m	small, 240 on longest side
  # -	medium, 500 on longest side
  # b	large, 1024 on longest side (only exists for very large original images)
  # o	original image, either a jpg, gif or png, depending on source format  
  class FlickrInterestingness < Component
    render do |tag|
      format = tag.attr['format'] || 's'
      displayed = tag.attr['per_page'] || '3'
      displayed = displayed.to_i
      per_page = displayed * 10 # grab 10x more images

      flickruri = 'http://api.flickr.com/services/xmlrpc/'
      server = XMLRPC::Client.new2(flickruri)
      flickrkey = '15b43fbd25e10d51e8533d32bf7e1d1a'
      details = {:api_key => flickrkey, :per_page => per_page}
      xml = server.call("flickr.interestingness.getList", details)
      doc = Nokogiri::XML(xml)
      builder = Builder::XmlMarkup.new

      chosen = (0..per_page-1).to_a.sort_by{rand}[0..displayed-1]

      index = 0
      doc.xpath("//photos/photo").each do |element|  
        if chosen.include?(index) 
          server = element["server"]
          id = element["id"]
          secret = element["secret"]
          title = element["title"]
          farm = element["farm"]
          image_url = "http://farm#{farm}.static.flickr.com/#{server}/#{id}_#{secret}_#{format}.jpg"

          builder.div(:id => "flickr_viewer") {
            builder.div(:id => "flickr_image") {
              builder.img(:src => image_url, :alt => title)
            }
          }
        end
        index = index + 1
      end
      builder.target!
    end  
  end
  
  class FlickrApp < Application
    home :home
  end
  
  class Home < Page
    template %[
      <html xml:lang="en" lang="en" 
            xmlns:trellis="http://trellisframework.org/schema/trellis_1_0_0.xsd" 
            xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <h1>Some Interesting Pictures...</h1>
          <h2>Default</h2>
          <div id='test1'>
            <trellis:flickr_interestingness/>
          </div>
          <h2>Parameterized</h2>
          <div id='test2'>
            <trellis:flickr_interestingness per_page='2' format='t' />
          </div>
        </body>
      </html>
    ], :format => :html
  end
  
  web_app = FlickrApp.new
  web_app.start 3006 if __FILE__ == $PROGRAM_NAME
end