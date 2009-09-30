#!/usr/bin/env ruby
 
#--
# Copyright &169;2001-2008 Integrallis Software, LLC. 
# All Rights Reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'trellis/utils'
require 'trellis/logging'
require 'rubygems'
require 'rack'
require 'radius'
require 'builder'
require 'hpricot'
require 'rexml/document'
require 'extensions/string'
require 'haml'
require 'markaby'
require 'redcloth'
require 'bluecloth'
require 'english/inflect'
require 'directory_watcher'

module Trellis

  # -- Application --
  # Represents a Trellis Web Application. An application can define one or more 
  # pages and it must define a home page or entry point into the application  
  class Application
    include Logging
    include Rack::Utils
    
    # descendant application classes get a singleton class level instances for 
    # holding homepage, dependent pages, static resource routing paths
    def self.inherited(child) #:nodoc:
      child.class_attr_reader(:homepage)
      child.attr_array(:static_routes)
      child.meta_def(:logger) { Application.logger }
      super
    end

    # class method that defines the homepage or entry point of the application
    # the entry point is the URL pattern / where the application is mounted
    def self.home(sym)
      @homepage = sym   
    end 
    
    # define url paths for static resources
    def self.map_static(urls = [], root = File.expand_path("#{File.dirname($0)}/../html/"))
      @static_routes << {:urls => urls, :root => root}
    end  
    
    # bootstrap the application
    def start(port = 3000)
      Application.logger.info "Starting Trellis Application #{self.class} on port #{port}"

      directory_watcher = configure_directory_watcher
      directory_watcher.start

      Rack::Handler::Mongrel.run configured_instance, :Port => port do |server|
        trap(:INT) do
          Application.logger.info "Exiting Trellis Application #{self.class}"
          directory_watcher.stop
          server.stop
        end
      end
    rescue Exception => e
      Application.logger.warn "#{ e } (#{ e.class })!"
    end
    
    def configured_instance
      # configure rack middleware
      application = Rack::ShowStatus.new(self)
      application = Rack::ShowExceptions.new(application)
      application = Rack::Reloader.new(application)
      application = Rack::CommonLogger.new(application, Application.logger)
      application = Rack::Session::Cookie.new(application)

      # set all static resource paths
      self.class.static_routes.each do |path|
        application = Rack::Static.new(application, path)
      end
      application
    end

    # find the first page with a suitable router, if none is found use the default router
    def find_router_for(request)
      match = Page.subclasses.values.find { |page| page.router && page.router.matches?(request) }
      match ? match.router : DefaultRouter.new(:application => self)
    end
    
    # implements the rack specification
    def call(env)
      response = Rack::Response.new
      request = Rack::Request.new(env)

      Application.logger.debug "request received with url_root of #{request.script_name}"

      session = env["rack.session"]

      router = find_router_for(request)
      route = router.route(request)
      
      page = route.destination.new if route.destination
      if page
        page.class.url_root = request.script_name
        page.path = request.path_info.sub(/^\//, '')
        page.inject_dependent_pages
        page.call_if_provided(:before_load)
        page.load_page_session_information(session)
        page.call_if_provided(:after_load)
        page.params = request.params.keys_to_symbols
        router.inject_parameters_into_page_instance(page, request)
        result = route.event ? page.process_event(route.event, route.value, route.source, session) : page

        # prepare the http response
        if (request.post? || route.event) && result.kind_of?(Trellis::Page)
          # for action events of posts then use redirect after post pattern
          # remove the events path and just return to the page
          path = result.path ? result.path.gsub(/\/events\/.*/, '') : result.class.class_to_sym
          response.status = 302
          response.headers["Location"] = "#{request.script_name}/#{path}"
        else
          # for render requests simply render the page
          response.body = result.kind_of?(Trellis::Page) ? result.render : result
          response.status = 200
        end
      else
        response.status = 404
      end
      response.finish
    end

    private

    def configure_directory_watcher(directory = nil)
      # set directory watcher to reload templates
      glob = []
      Page::TEMPLATE_FORMATS.each do |format|
        glob << "*.#{format}"
      end

      templates_directory = directory || "#{File.dirname($0)}/../html/"

      directory_watcher = DirectoryWatcher.new templates_directory, :glob => glob, :pre_load => true
      directory_watcher.add_observer do |*args|
        args.each do |event|
          Application.logger.debug "directory watcher: #{event}"
          event_type = event.type.to_s
          if (event_type == 'modified' || event_type == 'stable')
            template = event.path
            format = File.extname(template).delete('.').to_sym
            page_locator = Page.template_registry[template]
            page = Page.get_page(page_locator)
            Application.logger.info "reloading template for page => #{page}: #{template}"
            File.open(template, "r") { |f| page.template(f.read, :format => format) }
          end
        end
      end
      Application.logger.info "watching #{templates_directory} for template changes..."
      directory_watcher
    end
  end
  
  # -- Route --
  # A route object encapsulates an event, the event destination (target), the 
  # event source and an optional event value
  class Route
    attr_reader :destination, :event, :source, :value

    def initialize(destination, event = nil, source = nil, value = nil)
      @destination, @event, @source, @value = destination, event, source, value
    end
  end

  # -- Router --
  # A Router returns a Route in response to an HTTP request
  class Router
    EVENT_REGEX = %r{^(?:.+)/events/(?:([^/\.]+)(?:\.([^/\.]+)?)?)(?:/(?:([^\.]+)?))?}

    attr_reader :application, :pattern, :keys, :path, :page
    
    def initialize(options={})
      @application = options[:application]
      @path = options[:path]
      @page = options[:page]
      compile_path if @path
    end

    def route(request = nil)
      # get the event information if any
      value, source, event = request.path_info.match(EVENT_REGEX).to_a.reverse if request
      Route.new(@page, event, source, value)
    end

    def matches?(request)
      request.path_info.gsub(/\/events\/.*/, '').match(@pattern) != nil
    end

    def inject_parameters_into_page_instance(page, request)
      # extract parameters and named parameters from request
      if @pattern && @page && match = @pattern.match(request.path_info.gsub(/\/events\/.*/, ''))
        values = match.captures.to_a
        params =
          if @keys.any?
            @keys.zip(values).inject({}) do |hash,(k,v)|
              if k == 'splat'
                (hash[k] ||= []) << v
              else
                hash[k] = v
              end
              hash
            end
          elsif values.any?
            {'captures' => values}
          else
            {}
          end
        params.each_pair { |name, value| page.instance_variable_set("@#{name}".to_sym, value) }
      end
    end

    private

    # borrowed (stolen) from Sinatra!
    def compile_path
      @keys = []
      if @path.respond_to? :to_str
        special_chars = %w{. + ( )}
        pattern =
          @path.to_str.gsub(/((:\w+)|[\*#{special_chars.join}])/) do |match|
            case match
            when "*"
              @keys << 'splat'
              "(.*?)"
            when *special_chars
              Regexp.escape(match)
            else
              @keys << $2[1..-1]
              "([^/?&#]+)"
            end
          end
        @pattern = /^#{pattern}$/
      elsif @path.respond_to?(:keys) && @path.respond_to?(:match)
        @pattern = @path
        @keys = @path.keys
      elsif @path.respond_to? :match
        @pattern = path
      else
        raise TypeError, @path
      end
    end
  end
  
  # -- DefaultRouter --
  # The default routing scheme is in the form /page[.event[_source]][/value][?query_params]
  class DefaultRouter < Router
    ROUTE_REGEX = %r{^/([^/]+)(?:/(?:events/(?:([^/\.]+)(?:\.([^/\.]+)?)?)(?:/(?:([^\.]+)?))?)?)?}

    def route(request)
      value, source, event, destination = request.path_info.match(ROUTE_REGEX).to_a.reverse
      destination = @application.class.homepage unless destination
      page = Page.get_page(destination.to_sym)

      Route.new(page, event, source, value)
    end

    def matches?(request)
      request.path_info.match(ROUTE_REGEX) != nil
    end

    def self.to_uri(options={})
      url_root = options[:url_root]
      page = options[:page]
      event = options[:event]
      source = options[:source]
      value = options[:value]
      destination = page.kind_of?(Trellis::Page) ? (page.path || page.class.class_to_sym) : page
      url_root = page.kind_of?(Trellis::Page) && page.class.url_root ? "/#{page.class.url_root}" : '/' unless url_root
      source = source ? ".#{source}" : ''
      value = value ? "/#{value}" : ''
      event_info = event ? "/events/#{event}#{source}#{value}" : ''
      "#{url_root}#{destination}#{event_info}"
    end
  end
  
  # -- Page --
  # Represents a Web Page in a Trellis Application. A Page can contain multiple
  # components and it defines a template or view either as an external file 
  # (xml, xhtml, other) or programmatically using Markaby or HAML
  # A Trellis Page contains listener methods to respond to events trigger by 
  # components in the same page or other pages
  class Page

    TEMPLATE_FORMATS = [:html, :xhtml, :haml, :textile, :markdown]
    
    @@subclasses = Hash.new
    @@template_registry = Hash.new
    
    attr_accessor :params, :path, :logger
    
    def self.inherited(child) #:nodoc:
      @@subclasses[child.class_to_sym] = child
      
      child.instance_variable_set(:@name, child.underscore_class_name)
      child.attr_array(:pages, :create_accessor => false)
      child.attr_array(:components)
      child.attr_array(:stateful_components)
      child.attr_array(:persistents)
      child.class_attr_accessor :url_root
      child.class_attr_accessor :name
      child.class_attr_accessor :router
      child.class_attr_accessor :layout
      child.meta_def(:add_stateful_component) { |tid,clazz| @stateful_components << [tid,clazz] }
 
      locate_template child        
      super
    end  
    
    def self.template(body = nil, options = nil, &block)
      format = options[:format] if options
      if block_given?
        mab = Markaby::Builder.new({}, self, &block)
        html = mab.to_s
      else
        case format
        when :haml
          html = Haml::Engine.new(body).render
        when :textile  
          html = RedCloth.new(body).to_html
        when :markdown
          html = BlueCloth.new(body).to_html
        else # assume the body is (x)html 
          html = body
        end
      end
      @template = Hpricot.XML(html)
      find_components
    end
    
    def self.parsed_template
      # try to reload the template if it wasn't found on during inherited
      # since it could have failed if the app was not mounted as root
      unless @template
        Application.logger.debug "parsed template was no loaded, attempting to load..."
        locate_template(self)
      end 
      @template
    end

    def self.pages(*syms)
      @pages = @pages | syms
    end

    def self.route(path)
      router = Router.new(:path => path, :page => self)
      self.instance_variable_set(:@router, router)
    end
    
    def self.persistent(*fields)
      instance_attr_accessor fields
      @persistents = @persistents | fields    
    end
    
    def self.get_page(sym)
      @@subclasses[sym]
    end

    def self.subclasses
      @@subclasses
    end
    
    def initialize # TODO this is Ugly.... should no do it in initialize since it'll require super in child classes
      self.class.stateful_components.each do |id_component|
        id_component[1].enhance_page(self, id_component[0])
      end
      @logger = Application.logger
    end
    
    def process_event(event, value, source, session)
      method = source ? "on_#{event}_from_#{source}" : "on_#{event}"

      # execute the method passing the value if necessary 
      unless value
        method_result = send method.to_sym
      else
        method_result = send method.to_sym, value
      end

      # determine navigation flow based on the return value of the method call
      if method_result
        if method_result.kind_of?(Trellis::Page)
          page = method_result
          # save the current page persistent information
          if self != method_result
            save_page_session_information(session)
            page.inject_dependent_pages
            page.call_if_provided(:before_load)
          end

          # save the persistent information before rendering a response
          page.save_page_session_information(session)
        end
      end   
      
      method_result
    end
   
    def load_page_session_information(session)
      load_persistent_fields_data(session)
      load_stateful_components_data(session)
    end
    
    def save_page_session_information(session)
      save_persistent_fields_data(session)
      save_stateful_components_data(session)           
    end
    
    def render  
      call_if_provided(:before_render)
      result = Renderer.new(self).render
      call_if_provided(:after_render) 
      result      
    end
    
    # inject an instance of each of the injected pages classes as instance variables
    # of the current page
    def inject_dependent_pages
      self.class.inject_dependent_pages(self)
    end
    
    def self.inject_dependent_pages(target)
      @pages.each do |sym|
        clazz = Page.get_page(sym)
        if clazz
          Application.logger.debug "injecting an instance of #{clazz} for #{sym}"
          target.instance_variable_set("@#{sym}".to_sym, clazz.new)
          target.meta_def(sym) { instance_variable_get("@#{sym}") }
        else
          # throw an exception in production mode or
          # dynamically generate a page in development mode
        end
      end
    end

    def self.template_registry
      @@template_registry
    end
    
    private 
    
    def self.locate_template(clazz)   
      begin 
        if clazz.url_root.nil? || clazz.url_root.empty?
          dir = "#{File.dirname($0)}/../html/"
        else
          dir = "#{File.dirname($0)}#{clazz.url_root}/html/".gsub("Rack: ", '')
        end
        base = "#{clazz.underscore_class_name}"

        Application.logger.debug "looking for template #{base} in #{dir}"        

        TEMPLATE_FORMATS.each do |format|
          filename = "#{base}.#{format}"
          file = File.find_first(dir, filename)
          if file
            Application.logger.debug "found template for page => #{clazz}: #{filename}"
            File.open(file, "r") { |f| clazz.template(f.read, :format => format) }
            # add the template file to the external template registry so that we can reload it
            @@template_registry["#{dir}#{filename}"] = clazz.class_to_sym
            Application.logger.debug "registering template file for #{clazz.class_to_sym} => #{dir}#{filename}"
            break
          end
        end
      rescue Exception => e
        Application.logger.debug "no template found for page => #{clazz}: #{base} : #{e}"
      end        
    end
    
    def self.find_components
      @components.clear
      classes_processed = []
      doc = REXML::Document.new(@template.to_html)
      # look for component declarations in the template
      doc.elements.each('//trellis:*') do |element|
        # retrieve the component class
        component = Component.get_component(element.name.to_sym)
        # for components that are contained in other components
        # pass the parent information (parent tid)
        unless component.containers.empty?
          parent = nil
          # loop over all the container types until we find the matching parent
          component.containers.each do |container|
            parent = REXML::XPath.first(element, "ancestor::trellis:#{container}")
            break if parent
          end
          element.attributes['parent_tid'] = parent.attributes['tid'] if parent
        end
        
        tid = element.attributes['tid']
        unless component
          Application.logger.info "could not find #{element.name} in component hash"
        else
          # add component class to the page component list
          components << component          
          add_stateful_component(tid, component) #should I always do this? 
          process_component_contributions(component, classes_processed, element.attributes)   
          # also process any component dependencies - this should be recursive
          component.dependencies.each do |dependency|  
            components << dependency
            process_component_contributions(dependency, classes_processed)
          end          
        end
      end
    end 
    
    def self.process_component_contributions(component, classes_processed, attributes=nil)
      unless classes_processed.include?(component) 
        component.add_style_links_to_page(self, attributes)
        component.add_script_links_to_page(self, attributes)
        component.add_class_styles_to_page(self, attributes)
        component.add_class_scripts_to_page(self, attributes)
        component.add_document_modifications_to_page(self)
      end        

      component.add_styles_to_page(self, attributes)
      component.add_scripts_to_page(self, attributes)

      classes_processed << component unless classes_processed.include?(component)      
    end    
    
    def load_persistent_fields_data(session)
      self.class.persistents.each do |persistent_field|
        field = "@#{persistent_field}".to_sym
        current_value = instance_variable_get(field)
        new_value = session["#{self.class}_#{persistent_field}"]
        if current_value != new_value && new_value != nil
          instance_variable_set(field, new_value)
        end      
      end      
    end
    
    def load_stateful_components_data(session)
      self.instance_variables.each do |instance_variable_name|
        instance_variable = self.instance_variable_get(instance_variable_name.to_sym)
        instance_variable.load_component_session_information(self, instance_variable_name, session) if instance_variable.respond_to?(:load_component_session_information)
      end      
    end
    
    def save_persistent_fields_data(session)
      self.class.persistents.each do |persistent_field|
        session["#{self.class}_#{persistent_field}"] = instance_variable_get("@#{persistent_field}".to_sym)
      end       
    end
    
    def save_stateful_components_data(session)
      self.instance_variables.each do |instance_variable_name|
        instance_variable = self.instance_variable_get(instance_variable_name.to_sym)
        instance_variable.save_component_session_information(self, instance_variable_name, session) if instance_variable.respond_to?(:save_component_session_information)
      end      
    end    
  end # page
  
  # -- Renderer --
  # Responsible for processing tags/components in the page templates 
  # Uses the Radius context object onto which components registered themselves
  # (the tags that they respond to)
  class Renderer
    include Radius  
    
    def initialize(page)
      @page = page
      @context = Context.new
      
      # add all instance variables in the page as values accesible from the tags
      page.instance_variables.each do |var|
        value = page.instance_variable_get(var)
        unless value.kind_of?(Trellis::Page)
          sym = "#{var}=".split('@').last.to_sym
          @context.globals.send(sym, value)
        end
      end

      #TODO add public page methods to the context

      
      # add the page to the context too
      @context.globals.page = page
      
      # register the components contained in the page with the renderer's context
      page.class.components.each do |component|
        component.register_with_tag_context(@context)
      end 
      
      @parser = Parser.new(@context, :tag_prefix => 'trellis')
    end
    
    def render
      @parser.parse(@page.class.parsed_template.to_html)
    end
    
  end # renderer
  
  # -- Component --
  # The component represents a stateless (tag) or a stateful components. Trellis
  # components can provide contributions to the page. The contributions can be 
  # javascript, css stylesheets either at the class level or on a per instance 
  # basis. Components contain parameters that can be coerced or casted to a 
  # particular type before being handed to the event handling code
  class Component    
    # the page instance containing the component
    attr_accessor :page, :logger
    
    @@components = {}
    
    def initialize()
      @logger = Application.logger
    end
   
    def self.inherited(child) #:nodoc:     
      # component registration
      @@components[child.class_to_sym] = child

      child.class_attr_accessor(:body)
      child.class_attr_accessor(:cname)
      child.cname = child.underscore_class_name
      child.meta_def(:stateful?) { @stateful }
      
      child.attr_array(:fields, :create_accessor => false)
      child.attr_array(:style_links)
      child.attr_array(:script_links)
      child.attr_array(:scripts)
      child.attr_array(:class_scripts)
      child.attr_array(:styles)
      child.attr_array(:class_styles)      
      child.attr_array(:persistents)
      child.attr_array(:dependencies)
      child.attr_array(:document_modifications)
      child.attr_array(:containers)
      
      Application.logger.debug "registered component for tag #{child.cname} => class #{child}"
      super
    end 

    def self.tag_name(name)
      @cname = name
    end  

    def self.contained_in(*args)
      @containers = @containers | args
    end   

    def self.field(sym, options=nil)
      # extract options
      coherce_to = options[:coherce_to] if options
      default_value = options[:defaults_to] if options
      persistent = options[:persistent] if options
      
      @fields << sym
      
      # add an instance field to the component
      attr_accessor sym
      
      # store in array of persistent fields
      persistents << sym if persistent
      
      # castings
      if coherce_to
        meta_def("#{sym}=") do |value| 
          Application.logger.debug "casting value #{sym} to #{coherce_to}"
          self.instance_variable_set("@#{sym}", value)
        end
      end
     
      send("#{sym}=", default_value) if default_value
    end 
    
    def self.add_style_links_to_page(page, attributes)
      style_links.each do |href|  
        href = href.replace_ant_style_properties(attributes) if attributes
        builder = Builder::XmlMarkup.new
        link = builder.link(:rel => "stylesheet", :type => "text/css", :href => href)
        page.parsed_template.at("html/head").containers.last.after("\n#{link}")
      end
    end
    
    def self.add_script_links_to_page(page, attributes)
      script_links.each do |src|  
        src = src.replace_ant_style_properties(attributes) if attributes
        builder = Builder::XmlMarkup.new
        script = builder.script('', :type => "text/javascript", :src => src)
        page.parsed_template.at("html/head").containers.last.after("\n#{script}")
      end      
    end
    
    def self.add_class_styles_to_page(page, attributes)
      class_styles.each do |body|  
        body = body.replace_ant_style_properties(attributes) if attributes
        builder = Builder::XmlMarkup.new
        style = builder.style(:type => "text/css") do |builder|
          builder << body
        end
        page.parsed_template.at("html/head").containers.last.after("\n#{style}")
      end      
    end
    
    def self.add_class_scripts_to_page(page, attributes)
      class_scripts.each do |body|  
        body = body.replace_ant_style_properties(attributes) if attributes
        builder = Builder::XmlMarkup.new
        script = builder.script(:type => "text/javascript") do |builder|
          builder << body
        end
        page.parsed_template.at("html/body").containers.last.after("\n#{script}")
      end      
    end
    
    def self.add_styles_to_page(page, attributes)
      styles.each do |body|  
        body = body.replace_ant_style_properties(attributes) if attributes
        builder = Builder::XmlMarkup.new
        style = builder.style(:type => "text/css") do |builder|
          builder << body
        end
        page.parsed_template.at("html/head").containers.last.after("\n#{style}")
      end      
    end
    
    def self.add_scripts_to_page(page, attributes)
      scripts.each do |body|  
        body = body.replace_ant_style_properties(attributes) if attributes
        builder = Builder::XmlMarkup.new
        script = builder.script(:type => "text/javascript") do |builder|
          builder << body
        end
        page.parsed_template.at("html/body").containers.last.after("\n#{script}")
      end      
    end
    
    def self.add_document_modifications_to_page(page)
      document_modifications.each do |block| 
        page.parsed_template.instance_eval(&block)
      end
    end

    def self.page_contribution(sym, contribution=nil, options=nil, &block)
      unless (sym == :dom && block_given?)
        # add the contribution to the appropriate array of contributions
        # scripts, class_scripts, styles, class_styles, script_links, style_links
        scope = options[:scope] || :class if options
        receiver = sym.to_s.plural
        receiver = "class_#{receiver}" if scope == :class
        instance_variable_get("@#{receiver}").send(:<<, contribution)
      else
        @document_modifications << block
      end
    end    
    
    def self.get_component(sym)
      @@components[sym]
    end
    
    def self.render(&body) 
      @body = body
    end
    
    def self.register_with_tag_context(context)
      Application.logger.debug "registering #{self} with tag context"
      if @containers.empty?
        context.define_tag("#{@cname}", {}, &@body)
      else
        @containers.each do |container| 
          Application.logger.debug "=> registering tag name #{container}:#{@cname}"
          context.define_tag("#{container}:#{@cname}", {}, &@body)
        end
      end
    end 

    def self.is_stateful
      instance_variable_set "@stateful".to_sym, true
    end  
    
    def self.depends_on(*syms)
      syms.each do |sym|
        component = Component.get_component(sym)
        dependencies << component if component
      end
    end

    def save_component_session_information(page, instance_variable_name, session_data)
      self.class.persistents.each do |field|
        key = "#{page.class}_#{self.class}_#{instance_variable_name}_#{field}"
        session_data[key] = instance_variable_get("@#{field}".to_sym) if session_data
      end 
    end 

    def load_component_session_information(page, instance_variable_name, session_data)
      self.class.persistents.each do |field|
        field_sym = "@#{field}".to_sym
        current_value = instance_variable_get(field_sym)
        new_value = session_data["#{page.class}_#{self.class}_#{instance_variable_name}_#{field}"] if session_data
        if current_value != new_value && new_value != nil
          instance_variable_set(field_sym, new_value)
        end      
      end
    end
    
    private

    # - takes a page parameter
    # - adds an instance of the component with the given id to the page
    # - adds a wrapper method that
    #   - is named on_event_from_source where source is the specific component id
    #   - calls the component instance on_event method passing any params
    #   - responds with a redirect to a page or a value
    def self.enhance_page(page, id)
      if @stateful
        cname = @cname
        # create an instance of the component
        component_instance = self.new #TODO maybe this constructor can take the page
        # set the page on the instance of the component
        component_instance.page = page
        # set the component instance by id on the page
        page.instance_variable_set("@#{cname}_#{id}".to_sym, component_instance)
        # add an accessor method to get to the component instance 
        page.meta_def("#{cname}_#{id}") do 
          self.instance_variable_get("@#{cname}_#{id}".to_sym) 
        end
        # create pass-through methods for each event handler in the component (on_something methods)
        self.public_instance_methods.each do |method_name|
          if method_name.starts_with?('on_')
            page.meta_def("#{method_name}_from_#{cname}_#{id}") do |*args|
              result = page.instance_variable_get("@#{cname}_#{id}".to_sym).send(method_name.to_sym, *args)
              # if the method returns a page, navigate to that page, otherwise navigate to the source page
              (result && result.kind_of?(String)) ? result : page
            end
          end
        end
      end
    end 
  end
  
  # load trellis core components
  require 'trellis/component_library/core_components'
  require 'trellis/component_library/grid'
  require 'trellis/component_library/object_editor'
end