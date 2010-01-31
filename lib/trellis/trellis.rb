#!/usr/bin/env ruby
 
#--
# Copyright &169;2001-2008 Integrallis Software, LLC. 
# All Rights Reserved.
# process
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
require 'nokogiri'
require 'extensions/string'
require 'haml'
require 'markaby'
require 'redcloth'
require 'bluecloth'
require 'facets'
require 'directory_watcher'
require 'erubis'
require 'ostruct'
require 'advisable'

module Trellis
  
  TEMPLATE_FORMATS = [:html, :xhtml, :haml, :textile, :markdown, :eruby]

  # -- Application --
  # Represents a Trellis Web Application. An application can define one or more 
  # pages and it must define a home page or entry point into the application  
  class Application
    include Logging
    include Rack::Utils
    include Nokogiri::XML
    
    @@partials = Hash.new
    @@layouts = Hash.new
    @@filters = Hash.new
    
    # descendant application classes get a singleton class level instances for 
    # holding homepage, dependent pages, static resource routing paths
    def self.inherited(child) #:nodoc:
      child.class_attr_reader(:homepage)
      child.attr_array(:persistents)
      child.class_attr_reader(:session_config)
      child.attr_array(:static_routes)
      child.attr_array(:routers)
      child.meta_def(:logger) { Application.logger }
      child.instance_variable_set(:@session_config, OpenStruct.new({:impl => :cookie}))
      super
    end

    # class method that defines the homepage or entry point of the application
    # the entry point is the URL pattern / where the application is mounted
    def self.home(sym)
      @homepage = sym   
    end
    
    def self.session(sym, options={})
      @session_config = OpenStruct.new({:impl => sym, :options => options}) 
    end 
    
    # define url paths for static resources
    def self.map_static(urls = [], root = File.expand_path("#{File.dirname($0)}/../html/"))
      @static_routes << {:urls => urls, :root => root}
    end  
    
    # application-wide persistent fields
    def self.persistent(*fields)
      instance_attr_accessor fields
      @persistents = @persistents | fields    
    end
    
    def self.partials
      @@partials
    end
    
    def self.partial(name, body = nil, options = nil, &block)
      store_template(name, :partial, body, options, &block)
    end
    
    def self.layouts
      @@layouts
    end
    
    def self.layout(name, body = nil, options = nil, &block)
      store_template(name, :layout, body, options, &block)
    end
    
    def self.filters
      @@filters
    end
    
    def self.filter(name, kind = :before, &block)
      name = name.to_sym unless name.class == Symbol
      @@filters[name] = OpenStruct.new({:name => name, :kind => kind, :block => block}) 
    end
    
    # bootstrap the application
    def start(port = 3000)
      Application.logger.info "Starting Trellis Application #{self.class} on port #{port}"

      # only in development mode
      directory_watcher = configure_directory_watcher
      directory_watcher.start

      Rack::Handler::Mongrel.run configured, :Port => port do |server|
        trap(:INT) do
          Application.logger.info "Exiting Trellis Application #{self.class}"
          directory_watcher.stop
          server.stop
        end
      end
    rescue Exception => e
      Application.logger.warn "#{ e } (#{ e.class })!"
    end
    
    def configured
      # configure rack middleware
      application = Rack::ShowStatus.new(self)
      application = Rack::ShowExceptions.new(application)
      application = Rack::Reloader.new(application) # only in development mode
      application = Rack::CommonLogger.new(application, Application.logger)
      
      # configure rack session
      session_config = self.class.session_config
      case session_config.impl
      when :pool
        application = Rack::Session::Pool.new(application, session_config.options)
      when :memcached
        application = Rack::Session::Memcache.new(application, session_config.options)
      else
        application = Rack::Session::Cookie.new(application)
      end

      # set all static resource paths
      self.class.static_routes.each do |path|
        application = Rack::Static.new(application, path)
      end
      application
    end
    
    def self.routers 
      unless @routers
        @routers = Page.subclasses.values.collect { |page| page.router }.compact.sort {|a,b| b.score <=> a.score }
      end
      @routers
    end

    # find the first page with a suitable router, if none is found use the default router
    def find_router_for(request)
      match = Application.routers.find { |router| router.matches?(request) }
      match || DefaultRouter.new(:application => self)
    end
    
    # rack call interface.
    def call(env)
      dup.call!(env)
    end
    
    # implements the rack specification
    def call!(env)
      response = Rack::Response.new
      request = Rack::Request.new(env)

      Application.logger.debug "request received with url_root of #{request.script_name}" unless request.script_name.blank?

      session = env['rack.session'] ||= {}

      router = find_router_for(request)
      route = router.route(request)
      
      page = route.destination.new if route.destination
      if page
        load_persistent_fields_data(session)
        page.application = self
        page.class.url_root = request.script_name
        page.path = request.path_info.sub(/^\//, '')
        page.inject_dependent_pages
        page.call_if_provided(:before_load)
        page.load_page_session_information(session)
        page.call_if_provided(:after_load)
        page.params = request.params.keys_to_symbols
        router.inject_parameters_into_page_instance(page, request)

        result = route.event ? page.process_event(route.event, route.value, route.source, session) : page
        
        Application.logger.debug "response is #{result} an instance of #{result.class}"
        
        # -------------------------
        # prepare the http response
        # -------------------------
        
        # -------------------------------------
        # process the 'get' method if available
        # -------------------------------------
        same_class = true
        if result.kind_of?(Trellis::Page) && result.respond_to?(:get)
          result_cls = result.class
          result = result.get
          same_class = result.class == result_cls
          Application.logger.debug "processed get method, result.class is now => #{result.class}"
        end
        
        case result
        # -----------------
        # explicit redirect
        # -----------------
        when Trellis::Redirect
          result.process(request, response)
          Application.logger.debug "redirecting (explicit) to ==> #{request.script_name}/#{result.target}"      
        # -----------------
        # implicit redirect
        # -----------------
        when Trellis::Page
          # redirect after POST or 'get' method returns a different page
          if (request.post? || route.event) || !same_class
            path = result.path ? result.path.gsub(/\/events\/.*/, '') : result.class.class_to_sym
            response.status = 302
            response.headers["Location"] = "#{request.script_name}/#{path}"
            Application.logger.debug "redirecting (implicit) to ==> #{request.script_name}/#{path}"
          # simply render page
          else
            render_response(response, result.render)
            Application.logger.debug "rendering page #{result}"
          end
        # -------------------------------
        # stringify any other result type
        # -------------------------------
        else
          render_response(response, result.to_s)
          Application.logger.debug "rendering #{result}"
        end
      else
        response.status = 404
      end
      save_persistent_fields_data(session)
      response.finish
    end

    private
    
    def render_response(response, content)
      response.body = content
      response.status = 200
    end
    
    def self.store_template(name, type, body = nil, options = nil, &block)
      format = (options[:format] if options) || :html
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
          if type == :partial
            html = BlueCloth.new(body).to_html
          else 
            html = Markaby.build { thtml { body { text "#{BlueCloth.new(body).to_html}" } }}
          end
        else # assume the body is (x)html, also eruby is treated as (x)html at this point
          html = body
        end
      end
      template = Nokogiri::XML(html)
      case type
      when :layout
        @@layouts[name] = OpenStruct.new({:name => name, 
                                          :template => template, 
                                          :to_xml => template.to_xml, 
                                          :format => format})
      when :partial
        @@partials[name] = OpenStruct.new({:name => name, 
                                           :template => template, 
                                           :to_xml => template.to_xml(:save_with => Node::SaveOptions::NO_DECLARATION), 
                                           :format => format})
      end
    end
    
    def load_persistent_fields_data(session)
      self.class.persistents.each do |persistent_field|
        field = "@#{persistent_field}".to_sym
        current_value = instance_variable_get(field)
        new_value = session[persistent_field]
        if current_value != new_value && new_value != nil
          instance_variable_set(field, new_value)
        end      
      end      
    end
    
    def save_persistent_fields_data(session)
      self.class.persistents.each do |persistent_field|
        session[persistent_field] = instance_variable_get("@#{persistent_field}".to_sym)
      end       
    end

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
            page.load_template(template, format)
          end
        end
      end
      Application.logger.info "watching #{templates_directory} for template changes..."
      directory_watcher
    end
  end # application
  
  # -- Route --
  # A route object encapsulates an event, the event destination (target), the 
  # event source and an optional event value
  class Route
    attr_reader :destination, :event, :source, :value

    def initialize(destination, event = nil, source = nil, value = nil)
      @destination, @event, @source, @value = destination, event, source, value
    end
  end # route

  # -- Router --
  # A Router returns a Route in response to an HTTP request
  class Router
    EVENT_REGEX = %r{^(?:.+)/events/(?:([^/\.]+)(?:\.([^/\.]+)?)?)(?:/(?:([^\.]+)?))?}

    attr_reader :application, :pattern, :keys, :path, :page, :score
    
    def initialize(options={})
      @application = options[:application]
      @path = options[:path]
      @page = options[:page]
      if @path
        compile_path 
        compute_score
      else
        @score = 3 # since "/*" scores at 2
      end
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
        params << request.params
        params.each_pair { |name, value| page.instance_variable_set("@#{name}".to_sym, value) }
      end
    end
    
    def to_s
      @path
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
    
    def compute_score
      score = 0
      parts = @path.split('/').delete_if {|part| part.empty? }
      parts.each_index do |index| 
        part = parts[index]
        power = parts.size - index
        factor = part.match('\*') ? 1 : (part.match(':') ? 2 : 3)
        score = score + (factor * (2**index))
      end
      @score = score
    end
  end # router
  
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
      # get options
      url_root = options[:url_root]
      page = options[:page]
      event = options[:event]
      source = options[:source]
      value = options[:value]
      
      destination = page
      url_root = "/"
      
      if page.kind_of?(Trellis::Page)
        destination = page.path || page.class.class_to_sym
        root = page.class.url_root 
        url_root = (root && !root.empty?) ? "/#{root}" : '/'
      end

      source = source ? ".#{source}" : ''
      value = value ? "/#{value}" : ''
      event_info = event ? "/events/#{event}#{source}#{value}" : ''

      "#{url_root}#{destination}#{event_info}"
    end
  end # default_router
  
  # -- Redirect --
  # Encapsulates an HTTP redirect (is the object returned by Page#redirect method)
  class Redirect
    attr_reader :target, :status 
    
    def initialize(target, status=nil)
      status = 302 unless status
      raise ArgumentError.new("#{status} is not a valid redirect status") unless status >= 300 && status < 400
      @target, @status = target, status
    end
    
    def process(request, response)
      response.status = status 
      response["Location"] = "#{request.script_name}#{target.starts_with?('/') ? '' : '/'}#{target}"
    end
  end # redirect
  
  # -- Page --
  # Represents a Web Page in a Trellis Application. A Page can contain multiple
  # components and it defines a template or view either as an external file 
  # (xml, xhtml, other) or programmatically using Markaby or HAML
  # A Trellis Page contains listener methods to respond to events trigger by 
  # components in the same page or other pages
  class Page
    extend Advisable
    include Nokogiri::XML
    
    @@subclasses = Hash.new
    @@template_registry = Hash.new
    
    attr_accessor :application, :params, :path, :logger
    
    def self.inherited(child) #:nodoc:
      sym = child.class_to_sym
      @@subclasses[sym] = child if sym
      
      child.instance_variable_set(:@name, child.underscore_class_name)
      child.attr_array(:pages, :create_accessor => false)
      child.attr_array(:components)
      child.attr_array(:stateful_components)
      child.attr_array(:persistents)
      child.class_attr_accessor :url_root
      child.class_attr_accessor :name
      child.class_attr_accessor :router
      child.meta_def(:add_stateful_component) { |tid,clazz| @stateful_components << [tid,clazz] }
 
      locate_template child        
      super
    end  
    
    def self.layout
      @layout
    end
    
    def self.load_template(file, format)
      File.open(file, "r") { |f| self.template(f.read, :format => format) }
    end
    
    def self.template(body = nil, options = nil, &block)
      @format = (options[:format] if options) || :html
      @layout = (options[:layout] if options)
      if block_given?
        mab = Markaby::Builder.new({}, self, &block)
        html = mab.to_s
      else
        case @format
        when :haml
          html = Haml::Engine.new(body).render
        when :textile  
          html = RedCloth.new(body).to_html
        when :markdown
          if @layout
            html = BlueCloth.new(body).to_html
          else
            html = Markaby.build { thtml { body { text "#{BlueCloth.new(body).to_html}" } }}
          end
        else # assume the body is (x)html, also eruby is treated as (x)html at this point
          html = body
        end
      end
      
      # hack to prevent nokogiri form stripping namespace prefix on xml fragments
      if @layout 
        html = %[<div id="trellis_remove" xmlns:trellis="http://trellisframework.org/schema/trellis_1_0_0.xsd">#{html}</div>]
      end
      
      @template = Nokogiri::XML(html)

      find_components
    end
    
    def self.dom
      # try to reload the template if it wasn't found on during inherited
      # since it could have failed if the app was not mounted as root
      unless @template
        Application.logger.debug "parsed template was no loaded, attempting to load..."
        locate_template(self)
      end 
      @template
    end
    
    def self.to_xml(options = {})
      options[:no_declaration] ? dom.to_xml(:save_with => Node::SaveOptions::NO_DECLARATION) : dom.to_xml
    end
    
    def self.format
      @format
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
    
    def self.apply_filter(name, options = {})
      filter = Application.filters[name]
      methods = options[:to] == :all ? self.public_instance_methods(false) : [options[:to]]
      methods << :get if options[:to] == :all
      methods = methods - [:before_load, :after_load, :before_render, :after_render, :underscore_class_name]
      Application.logger.debug "in #{self} applying filter #{name} to methods: #{methods.join(', ')}"
      
      methods.each do |method|
        case filter.kind
        when :around
          around method do |target| 
            filter.block.call(self) { target.call } 
          end
        when :before
          before method do filter.block.call(self) end
        when :after 
          after method do filter.block.call(self) end
        end
      end
    end
    
    def self.get_page(sym)
      @@subclasses[sym]
    end

    def self.subclasses
      @@subclasses
    end
    
    def initialize # TODO this is Ugly.... should not do it in initialize since it'll require super in child classes
      self.class.stateful_components.each do |id_component|
        id_component[1].enhance_page(self, id_component[0])
      end
      @logger = Application.logger
    end
    
    def get; self; end
    
    def redirect(path, status=nil)
      Redirect.new(path, status)
    end
    
    def process_event(event, value, source, session)
      method = source ? "on_#{event}_from_#{source}" : "on_#{event}"

      # execute the method passing the value if necessary
      method_result = value ? send(method.to_sym, Rack::Utils.unescape(value)) : send(method.to_sym)

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
      process_stateful_component_data(:load, session)
    end
    
    def save_page_session_information(session)
      save_persistent_fields_data(session)      
      process_stateful_component_data(:save, session)   
    end
    
    def render  
      call_if_provided(:before_render)
      result = Renderer.new(self).render
      call_if_provided(:after_render) 
      result      
    end
    
    def render_partial(name, locals={})
      Renderer.new(self).render_partial(name, locals)
    end
    
    # inject an instance of each of the injected pages classes as instance variables
    # of the current page
    def inject_dependent_pages
      self.class.inject_dependent_pages(self)
    end
    
    def self.inject_dependent_pages(target)
      @pages.each do |sym|
        clazz = Page.get_page(sym)
        # if the injected page class is not found
        # throw an exception in production mode or
        # dynamically generate a page in development mode
        unless clazz
          target_class = sym.to_s.camelcase(:upper)
          Application.logger.debug "creating stand in page class #{target_class} for symbol #{sym}"

          clazz = Page.create_child(target_class) do

            def method_missing(sym, *args, &block)
              Application.logger.debug "faking response to #{sym}(#{args}) from #{self} an instance of #{self.class}"
              self
            end

            template do
              thtml {
                head { title "Stand-in Page" }
                body { h1 { text %[Stand-in Page for <trellis:value name="page_name"/>] }}
              }
            end
          end
          Page.subclasses[sym] = clazz
        end
        
        Application.logger.debug "injecting an instance of #{clazz} for #{sym}"
        target.instance_variable_set("@#{sym}".to_sym, clazz.new)
        target.meta_def(sym) { instance_variable_get("@#{sym}") }
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
            clazz.load_template(file, format)
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
      # look for component declarations in the template
      @template.xpath("//trellis:*", 'trellis' => "http://trellisframework.org/schema/trellis_1_0_0.xsd").each do |element|
        # retrieve the component class
        component = Component.get_component(element.name.to_sym)
        # for components that are contained in other components
        # pass the parent information (parent tid)
        unless component.containers.empty?
          parent = nil
          # loop over all the container types until we find the matching parent
          component.containers.each do |container|
            parent = element.xpath("ancestor::trellis:#{container}", 'trellis' => "http://trellisframework.org/schema/trellis_1_0_0.xsd").first
            break if parent
          end
          element['parent_tid'] = parent['tid'] if parent
        end
        
        tid = element['tid']
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
        [:style_links, :script_links, :class_styles, :class_scripts].each do |what|
          component.add_to_page(self, what, attributes)
        end
        component.add_document_modifications_to_page(self)
      end        

      component.add_to_page(self, :styles, attributes)
      component.add_to_page(self, :scripts, attributes)

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
    
    def save_persistent_fields_data(session)
      self.class.persistents.each do |persistent_field|
        session["#{self.class}_#{persistent_field}"] = instance_variable_get("@#{persistent_field}".to_sym)
      end       
    end
    
    def process_stateful_component_data(action, session)
      self.instance_variables.each do |instance_variable_name|
        instance_variable = self.instance_variable_get(instance_variable_name.to_sym)
        case action
        when :load
          instance_variable.load_component_session_information(self, instance_variable_name, session) if instance_variable.respond_to?(:load_component_session_information)
        when :save
          instance_variable.save_component_session_information(self, instance_variable_name, session) if instance_variable.respond_to?(:save_component_session_information)
        end
      end
    end
        
  end # page
  
  # -- Renderer --
  # Responsible for processing tags/components in the page templates 
  # Uses the Radius context object onto which components registered themselves
  # (the tags that they respond to)
  class Renderer
    include Radius  
    
    SKIP_METHODS = ['before_load', 'after_load', 'before_render', 'after_render', 'get']
    INCLUDE_METHODS = ['render_partial']
    
    def initialize(page)
      @page = page
      configure_context
    end
        
    def render
      preprocessed = ""
      layout_id = @page.class.layout
      template = layout_id ? @page.class.to_xml(:no_declaration => true) : @page.class.to_xml

      if layout_id
        # page has a layout 
        # retrieve the layout from the application
        layout = Application.layouts[layout_id]
        # render the page template to a variable
        if @page.class.format == :eruby
          body = Erubis::PI::Eruby.new(template, :trim => false).evaluate(@eruby_context)
          @eruby_context[:body] = body
        else
          @eruby_context[:body] = template
        end
        
        # render the layout around the page template
        preprocessed = Erubis::PI::Eruby.new(layout.to_xml, :trim => false).evaluate(@eruby_context)
        
        # clean up nokogiri namespace hack, see Page#template
        doc = Nokogiri::XML(preprocessed)
        to_be_removed = doc.at_css(%[div[id="trellis_remove"]])
        parent = to_be_removed.parent
        to_be_removed.children.each { |child| child.parent = parent }
        to_be_removed.remove
        preprocessed = doc.to_xml
      else
        # page has no layout
        if @page.class.format == :eruby
          preprocessed = Erubis::PI::Eruby.new(template, :trim => false).evaluate(@eruby_context)
        else
          preprocessed = template
        end
      end
      # radius parsing
      @parser.parse(preprocessed)
    end
    
    def render_partial(name, locals={})
      partial = Application.partials[name]
      if partial
        if partial.format == :eruby
          locals.each_pair { |n,v| @eruby_context[n] = v }
          preprocessed = Erubis::PI::Eruby.new(partial.to_xml, :trim => false).evaluate(@eruby_context)
          @parser.parse(preprocessed)
        else
          @parser.parse(partial.to_xml)
        end        
      end
    end
    
    private
    
    def configure_context
      @context = Context.new
      # context for erubis templates
      @eruby_context = Erubis::Context.new #if @page.class.format == :eruby
      
      # add all instance variables in the page as values accesible from the tags
      @page.instance_variables.each do |var|
        value = @page.instance_variable_get(var)
        unless value.kind_of?(Trellis::Page)
          sym = "#{var}=".split('@').last.to_sym
          @context.globals.send(sym, value)
          @eruby_context["#{var}".split('@').last] = value #if @eruby_context
        end
      end

      # add other useful values to the tag context
      @context.globals.send(:page_name=, @page.class.to_s)
      @eruby_context[:page_name] = @page.class.to_s #if @eruby_context

      # add public page methods to the context      
      add_method_to_context(@page.public_methods(false), @page)
      
      # add page helper methods to the context      
      add_method_to_context(INCLUDE_METHODS, @page) 
      
      # add public application methods to the context
      add_method_to_context(@page.application.public_methods(false), @page.application)

      # add the page to the context too
      @context.globals.page = @page
      @eruby_context[:page] = @page
      
      # register the components contained in the page with the renderer's context
      @page.class.components.each do |component|
        component.register_with_tag_context(@context)
      end 
      
      @parser = Parser.new(@context, :tag_prefix => 'trellis')
    end
    
    def add_method_to_context(methods, target)
      methods.each do |method_name|
        # skip event handlers and the 'get' method
        unless method_name.starts_with?('on_') || SKIP_METHODS.include?(method_name)
          @eruby_context.meta_def(method_name) do |*args|
            target.send(method_name.to_sym, *args)
          end #if @eruby_context
          @context.globals.meta_def(method_name) do |*args|
            target.send(method_name.to_sym, *args)
          end
        end 
      end
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
    
    def self.add_to_page(page, what, attributes)
      builder = Builder::XmlMarkup.new
      collection = self.send(what)
      location = [:class_scrips, :scripts].include?(what) ? "html/body" : "html/head"
      collection.each do |element|
        element = element.replace_ant_style_properties(attributes) if attributes
        case what
        when :style_links
          value = builder.link(:rel => "stylesheet", :type => "text/css", :href => element)
        when :script_links
          value = builder.script('', :type => "text/javascript", :src => element)
        when :class_styles, :styles
          value = builder.style(:type => "text/css") { |builder| builder << element }
        when :class_scripts, :scripts
          value = builder.script(:type => "text/javascript") { |builder| builder << element }
        end
        page.dom.at_css(location).children.last.after("\n#{value}")
      end
    end
    
    def self.add_document_modifications_to_page(page)
      document_modifications.each do |block| 
        page.dom.instance_eval(&block)
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
        key = generate_data_session_id(page, instance_variable_name, field)
        session_data[key] = instance_variable_get("@#{field}".to_sym) if session_data
      end 
    end 

    def load_component_session_information(page, instance_variable_name, session_data)
      self.class.persistents.each do |field|
        field_sym = "@#{field}".to_sym
        current_value = instance_variable_get(field_sym)
        key = generate_data_session_id(page, instance_variable_name, field)
        new_value = session_data[key] if session_data
        if current_value != new_value && new_value != nil
          instance_variable_set(field_sym, new_value)
        end      
      end
    end
    
    private
    
    def generate_data_session_id(page, instance_variable_name, field)
      "#{page.class}_#{self.class}_#{instance_variable_name}_#{field}"
    end

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
  end # component
  
  # load trellis core components
  require 'trellis/component_library/core_components'
  require 'trellis/component_library/grid'
  require 'trellis/component_library/object_editor'
end
