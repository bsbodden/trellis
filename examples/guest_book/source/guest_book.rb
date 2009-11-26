require 'rubygems'
require 'trellis'

include Trellis

module GuestBookApp

  class Comment
    attr_accessor :text
    attr_accessor :time_stamp

    def initialize(text, time_stamp=Time.now)
      @text, @time_stamp = text, time_stamp
    end
  end
  
  class GuestBookApp < Application
    home :guest_book
  end
  
  class GuestBook < Page 
    persistent :comments 
    
    def initialize
      @comments = Array.new
      super
    end
    
    def on_submit_from_comment  
      text = params[:comment_text]
      @comments << Comment.new(text)
      logger.info "there are #{@comments.size.to_s} comments"
      self
    end

    template(%[
!!! XML
!!! Strict
%html{ :xmlns => "http://www.w3.org/1999/xhtml",
       "xmlns:trellis" => "http://trellisframework.org/schema/trellis_1_0_0.xsd" }
  %head
    %title
      Trellis Guest Book
  %body
    %trellis:form{ :tid => "comment", :method => "post" }
      Add your comment here:
      %p
      %trellis:text_area{ :keep_contents => "no", :tid => "text", :rows => "15", :cols => "60" }
      %p
      %trellis:submit{ :tid => "add", :value => "Submit" }
    %p
    %trellis:each{ :value => "comment", :source => "comments" }
      %p
      %trellis:value{ :name => "comment.time_stamp" }
      %br
      %trellis:value{ :name => "comment.text" }
      %br
    ], :format => :haml)
  end
  
  GuestBookApp.new.start 3001 if __FILE__ == $PROGRAM_NAME
end
