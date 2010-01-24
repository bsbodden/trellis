module FiltersApp
  class FiltersApp < Trellis::Application
    attr_accessor :allow
    home :protected_one
    
    filter :authorized?, :around do |page, &block|
      page.application.allow ? block.call : page.redirect("/not_authorized")
    end
     
    filter :capitalize, :after do |page|
      page.answer = page.answer.reverse
    end
  end
  
  class ProtectedOne < Trellis::Page 
    apply_filter :authorized?, :to => :all
    template %[<p>protected one</p>], :format => :html
  end
  
  class ProtectedTwo < Trellis::Page 
    apply_filter :authorized?, :to => :all
    def get; self; end
    template %[<p>protected two</p>], :format => :html
  end
  
  class ProtectedThree < Trellis::Page
    persistent :answer 
    apply_filter :authorized?, :to => :on_knock_knock
    apply_filter :capitalize, :to => :on_knock_knock
     
    def initialize; @answer = "blah"; end
    
    def on_knock_knock
      @answer = "who's there?"
      self
    end

    template %[<p>@{@answer}@</p>], :format => :eruby
  end
  
  class NotAuthorized < Trellis::Page
    template %[not authorized], :format => :html
  end  
end