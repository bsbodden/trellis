require 'rubygems'
require 'trellis'

include Trellis

module Simplest
  
  class Simplest < Application
    home :start
  end
  
  class Start < Page 
    attr_accessor :current_time 
    
    def initialize
      @current_time = Time.now
    end
    
    template do # using Markaby
      xhtml_strict { 
        head { title "Simplest Trellis Application" }
        body { 
          h1 "Simplest Trellis Application" 
          p "One Application, One Page, Two Components"
          p "The time below should change after each request."
          p {
            text "The current time is: "
            text %[<trellis:value name="current_time">${currentTime}.</trellis:value>]
          }
          p {
            text %[[<trellis:page_link tpage="start">refresh</trellis:page_link>]]
          }
        }
      } 
    end
  end
  
  Simplest.new.start if __FILE__ == $PROGRAM_NAME
end
