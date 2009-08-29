module TestApp
  class MyApp < Trellis::Application
    home :home
    pages :other
    
    map_static ['/images', '/style', '/favicon.ico']
    map_static ['/yui'], "./js" 
  end

  class Home < Trellis::Page 
    pages :other
    
    template do html { body { h1 "Hello World!" }} end
      
    def on_event1 
      self
    end
    
    def on_event2 
      "just some text"
    end
    
    def on_event3 
      @other
    end
  end
  
  class Other < Trellis::Page    
    template do html { body { p "Goodbye Cruel World " }} end
  end
  
  class BeforeLoad < Trellis::Page
    attr_reader :some_value
    
    def before_load
      @some_value = "8675309"
    end
    
    template do html { body { text %[<trellis:value name="some_value"/>] }} end
  end
  
  class AfterLoad < Trellis::Page
    attr_reader :some_value
    
    def after_load
      @some_value = "chunky bacon!"
    end
    
    template do html { body { text %[<trellis:value name="some_value"/>] }} end
  end  
end
