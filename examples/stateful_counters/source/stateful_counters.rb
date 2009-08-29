require 'rubygems'
require 'trellis'

include Trellis

# http://seaside.st/about/examples/multicounter
# This example shows 
# - a custom stateful component that can be use repeatedly in a page.
module StatefulCounters

  class Counter < Component
    is_stateful
    
    tag_name "counter"
   
    field :value, :persistent => true
    
    def initialize
      reset
    end
     
    render do |tag|
      tid = tag.attr['tid']
      page = tag.globals.page
      counter = page.send("counter_#{tid}")
      value = counter.value
      
      builder = Builder::XmlMarkup.new
      builder.div(:id => tid) {
        builder.h1(value)
        builder.a("++", :href => "/#{page.class.name}.add_counter#{tid}")
        builder.text(" ")      
        builder.a("--", :href => "/#{page.class.name}.subtract_counter#{tid}")   
      }
    end
    
    def on_add
      @value = @value + 1
    end
    
    def on_subtract
      @value = @value - 1
    end
    
    def reset
      @value = 0
    end
  end
  
  class CountersApp < Application
    home :counters
    
    map_static ['/images', '/style', '/favicon.ico']
  end
  
  class Counters < Page
    def on_select_from_reset
      # reset all counters on the page
      @counter_one.reset
      @counter_two.reset
      @counter_three.reset
      self
    end  
  end
  
  web_app = CountersApp.new
  web_app.start 3005 if __FILE__ == $PROGRAM_NAME 
end