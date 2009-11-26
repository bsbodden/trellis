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
      Date.parse("#{@month}/#{@day}/#{@year}")
    end

    def on_select
      self
    end

    template do
      thtml {
        body {
          h2 {
            text %[Date <trellis:value name="page.parse_date"/>]
          }
          text %[is the <trellis:eval expression="Date.parse(month + '/' + day + '/' + year).yday.to_s"/> day of the year]
          br
          text %[<trellis:action_link>Refresh</trellis:action_link>]
        }
      }
    end
  end

  Routing.new.start if __FILE__ == $PROGRAM_NAME
end

