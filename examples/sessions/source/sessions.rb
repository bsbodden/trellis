require 'rubygems'
require 'trellis'

include Trellis

module Sessions
  
  class Sessions < Application
    home :start
    
    session :pool, { :key => 'rack.session', :path => '/', :expire_after => 2592000 }
  end
  
  class Start < Page 
    persistent :results 
    
    def on_select
      logger.info "processing on_select"
      @results = rand(9)
      self
    end
    
    template do # using Markaby
      xhtml_strict { 
        head { title "Simplest Trellis Application" }
        body { 
          h1 "Persistent Fields via Session" 
          p "This application uses Rack::Session::Pool for in-memory, cookie backed HTTP sessions"
          p {
            text "The value is: "
            text %[<trellis:value name="results">${results}.</trellis:value>]
          }
          p {
            text %[[<trellis:action_link>Click Me</trellis:action_link>]]
          }
        }
      } 
    end
  end
  
  Sessions.new.start 3012 if __FILE__ == $PROGRAM_NAME
end
