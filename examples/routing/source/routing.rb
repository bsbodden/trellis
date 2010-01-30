require 'rubygems'
require 'trellis'

include Trellis

module Routing

  class Routing < Application
    home :home
    logger.level = DEBUG
  end

  class Home < Trellis::Page
    template do html { body { text %[this is the home page] }} end
  end

  class RoutedDifferently < Trellis::Page
    route '/whoa'

    template do html { body { text %[whoa!] }} end
  end

  class RoutedDifferentlyWithParams < Trellis::Page
    route '/day_of_the_year/:year/:month/:day'

    def parse_date
      Date.parse("#{@month}/#{@day}/#{@year}").strftime("%e %B, %Y")
    end

    def on_select
      self
    end
    
    template %[
      <html xml:lang="en" lang="en" 
           xmlns:trellis="http://trellisframework.org/schema/trellis_1_0_0.xsd" 
           xmlns="http://www.w3.org/1999/xhtml">
       <h2>@{parse_date}@ is the @{Date.parse(@month + '/' + @day + '/' + @year).yday.ordinalize.to_s}@ day of the year!</h2>
       <br/>
       <trellis:action_link>Refresh</trellis:action_link>
      </html>
    ], :format => :eruby
  end

  Routing.new.start if __FILE__ == $PROGRAM_NAME
end

