module TestComponents
  
  class SimpleComponent < Trellis::Component
    tag_name "simple_component"

    render do |tag|
      "hello from simple component"
    end
  end

  class Counter < Trellis::Component
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
      href_add = Trellis::DefaultRouter.to_uri(:page => page.class.name,
                                      :event => 'add',
                                      :source => "counter_#{tid}")
      href_subtract = Trellis::DefaultRouter.to_uri(:page => page.class.name,
                                      :event => 'subtract',
                                      :source => "counter_#{tid}")
      builder = Builder::XmlMarkup.new
      builder.div(:id => tid) {
        builder.text!(value.to_s)
        builder.a("++", :href => href_add)
        builder.a("--", :href => href_subtract)
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

  class Contributions < Trellis::Component
    #tag_name "contributions"

    # -----------------------
    # component contributions
    # -----------------------
    page_contribution :style_link, "/someplace/my_styles.css"
    page_contribution :script_link, "/someplace/my_script.js"
    page_contribution :style, %[html { color:#555555; background-color:#303030; }], :scope => :class
    page_contribution :style, %[/* just a comment */], :scope => :instance
    page_contribution :script, %[alert('hello from ${tid}');], :scope => :instance
    page_contribution :script, %[alert('hello just once');], :scope => :class
    
    page_contribution(:dom) {
      at("body")['class'] = 'new_class'
    }

    render do |tag|
      "hear ye, hear ye!"
    end
  end

  class ApplicationWithComponents < Trellis::Application
    home :page_with_simple_component
  end

  class PageWithSimpleComponent < Trellis::Page
    template do thtml { body { text %[<trellis:simple_component/>] }} end
  end

  class PageWithStatefulComponent < Trellis::Page
    route '/counters'

    template do
      thtml {
        body {
          text %[
                 <trellis:counter tid="one" />
                 <hr/>
                 <trellis:counter tid="two" />
                 <hr/>
                 <trellis:counter tid="three" />
               ]
        }
      }
    end
  end

  class PageWithContributions < Trellis::Page
    template do
      thtml {
        head {
          title "counters"
        }
        body {
          text %[<trellis:contributions tid="one"/><trellis:contributions tid="two"/>]
        }
      }
    end
  end
end
