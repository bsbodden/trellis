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

require 'trellis/trellis'
require 'paginator'

module Trellis
  module CoreComponents
    
    # Component that triggers an action on the server with a subsequent full 
    # page refresh
    #
    class ActionLink < Trellis::Component
      render do |tag|
        source = tag.attr['tid'] 
        context = tag.attr['context']
        target_page = tag.attr['page'] || tag.globals.page.class.name
        url_root = tag.globals.page.class.url_root
        
        if context
          value = tag.locals.instance_eval(context) || tag.globals.instance_eval(context)
        end
        
        if source
          if context
            id = "#{source}_#{value}"          
            href = "#{url_root}/#{target_page}.select_#{source}/#{value}"            
          else
            id = "#{source}"
            href = "#{url_root}/#{target_page}.select_#{source}"             
          end
        else
          if context
            id = "action_link_#{value}"          
            href = "#{url_root}/#{target_page}.select/#{value}"            
          else
            id = "action_link"
            href = "#{url_root}/#{target_page}.select"             
          end          
        end
        
        builder = Builder::XmlMarkup.new
        text = builder.a('${contents}', "href" => href, "id" => id)
        text.replace_ant_style_property('contents', tag.expand)
      end
    end      
     
    #
    #
    #
    class Loop < Trellis::Component
      render do |tag|
        value_name = tag.attr['value']
        value = "#{value_name}="
        # make value available by name to the page   
        source = tag.attr['source']
        start, finish = source.split('..')
        content = ''
        (start..finish).each do |n|
          tag.locals.send(value.to_sym, n) 
          content << tag.expand
        end
        content
      end 
    end      

    #
    #
    #
    class Each < Trellis::Component
      render do |tag|
        value_name = tag.attr['value']
        value = "#{value_name}="
        # make value available by name to the page   
        source = tag.attr['source']
        begin
          iterator = tag.locals.instance_eval(source) || tag.globals.instance_eval(source)
        rescue NoMethodError
          iterator = []
        end
        content = ''
        iterator.each do |n|
          tag.locals.send(value.to_sym, n) 
          content << tag.expand
        end if iterator
        content
      end 
    end      
      
    #
    #
    #
    class Value < Trellis::Component
      render do |tag|
        name = tag.attr['name']
        unless name.include?('.')
          value = tag.locals.send(name.to_sym) || tag.globals.send(name.to_sym)
        else
          target_name, method = name.split('.')
          target = tag.locals.send(target_name.to_sym) || tag.globals.send(target_name.to_sym)
          value = target.send(method.to_sym) if target
        end 
        value
      end
    end

    class Eval < Trellis::Component
      render do |tag|
        expression = tag.attr['expression']
        tag.locals.instance_eval(expression) if expression
      end
    end
      
    #
    #
    #
    class PageLink < Trellis::Component
      render do |tag|
        url_root = tag.globals.page.class.url_root
        page_name = tag.attr['tpage']
        id = tag.attr['tid'] || page_name
        href = "#{url_root}/#{page_name}"
        contents = tag.expand
        builder = Builder::XmlMarkup.new
        builder.a(contents, "href" => href, "id" => "page_link_#{id}")
      end
    end
      
    #
    #
    #
    class Img < Trellis::Component
      render do |tag|
        attrs = tag.attr.exclude_keys('src', 'alt')
        
        # resolve the ${} variables 
        attrs['src'] = Utils.expand_properties_in_tag(tag.attr['src'], tag)
        attrs['alt'] = Utils.expand_properties_in_tag(tag.attr['alt'], tag)
        
        builder = Builder::XmlMarkup.new
        builder.img(attrs)
      end
    end
      
    #
    #
    #
    class Remove < Trellis::Component
      render do |tag|
        # do nothing
      end
    end
    
    #
    #
    #
    class If < Trellis::Component
      render do |tag|
        # resolve the ${} variables  
        test = Utils.expand_properties_in_tag(tag.attr['test'], tag)  

        # TODO I'm suspecting this is buggy! plus should we catch exceptions?
        local = tag.locals.instance_eval(test)
        global = tag.globals.instance_eval(test)        
        
        result = false
        if local
          result = local
        elsif global
          result = global
        end
   
        content = ''
        if result 
          content << tag.expand
        else 
          # find the else tag and expand it
        end
        content
      end
    end
    
    #
    #
    #
    class Unless < Trellis::Component
      render do |tag|
        # resolve the ${} variables  
        test = Utils.expand_properties_in_tag(tag.attr['test'], tag)  

        local = tag.locals.instance_eval(test)
        global = tag.globals.instance_eval(test)        
        
        result = false
        if local
          result = !local
        elsif global
          result = !global
        end
   
        content = ''
        if result 
          content << tag.expand
        else 
          # find the else tag and expand it
        end
        content
      end
    end
    
    #
    #
    #
    class Button < Trellis::Component
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.attr['tid']}"
        contents = tag.expand        
        builder = Builder::XmlMarkup.new
        builder.button(contents, attrs)          
      end
    end
      
    #
    #
    #
    class Form < Trellis::Component
      render do |tag|
        url_root = tag.globals.page.class.url_root
        form_name = tag.attr['tid']
        on_behalf = tag.attr['on_behalf']
        method = tag.attr['method'] || 'GET'
        tag.locals.form_name = form_name        
        href = "#{url_root}/#{tag.globals.page.class.name}.submit_#{(on_behalf ? on_behalf : form_name)}"        
        builder = Builder::XmlMarkup.new
        builder.form("name" => form_name, "action" => href, "method" => method) do |form|
          form << tag.expand
        end
      end
    end     
     
    #
    #
    #
    class Submit < Trellis::Component
      tag_name "submit"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        attrs['type'] = 'submit'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)
      end
    end      
      
    #
    #
    #
    class CheckBox < Trellis::Component
      tag_name "check_box"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        attrs['type'] = 'checkbox'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)
      end
    end
    
    #
    #
    #
    class TextField < Trellis::Component
      tag_name "text_field"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type', 'value')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        value = tag.attr['value']
        literal = tag.attr['literal'] =~ /^(y|yes|true)$/
        if value 
          if !literal
            resolved_value = ''
            unless value.include?('.')
              resolved_value = tag.locals.send(value.to_sym) || tag.globals.send(value.to_sym)
            else
              target_name, method = value.split('.')
              target = tag.locals.send(target_name.to_sym) || tag.globals.send(target_name.to_sym)
              resolved_value = target.send(method.to_sym) if target
            end 
            attrs['value'] = resolved_value if resolved_value
          else
            attrs['value'] = value
          end
        end
        
        attrs['type'] = 'text'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)       
      end
    end
    
    #
    #
    #
    class TextArea < Trellis::Component
      tag_name "text_area"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'keep_contents')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"  
        keep_contents = tag.attr['keep_contents']  
        if keep_contents        
          contents = keep_contents =~ /^(y|yes|true)$/ ? tag.expand : ''
        else
          contents = ''
        end
        builder = Builder::XmlMarkup.new
        builder.textarea(contents, attrs)
      end 
    end 
    
    #
    #
    #
    class Password < Trellis::Component
      tag_name "password"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        attrs['type'] = 'password'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)       
      end
    end
      
    #
    #
    #
    class Hidden < Trellis::Component
      tag_name "hidden"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type', 'value')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        value = tag.attr['value']
        literal = tag.attr['literal'] =~ /^(y|yes|true)$/
        if value 
          if !literal
            resolved_value = ''
            unless value.include?('.')
              resolved_value = tag.locals.send(value.to_sym) || tag.globals.send(value.to_sym)
            else
              target_name, method = value.split('.')
              target = tag.locals.send(target_name.to_sym) || tag.globals.send(target_name.to_sym)
              resolved_value = target.send(method.to_sym)
            end 
            attrs['value'] = resolved_value
          else
            attrs['value'] = value
          end
        end
        
        attrs['type'] = 'hidden'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)        
      end
    end
      
    #
    #
    #
    class Select < Trellis::Component    
      tag_name "select"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'select_if', 'selected_value', 'source')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        expression = tag.attr['source'] # something we can iterate over
        selected = Utils.evaluate_tag_attribute('select_if', tag)
        selected_value = Utils.evaluate_tag_attribute('selected_value', tag)
        value_accessor = Utils.expand_properties_in_tag(tag.attr['value'], tag)
        
        builder = Builder::XmlMarkup.new
        builder.select(attrs) do 
          if expression.include? '..'
            start, finish = expression.split('..')
            (start..finish).each do |item|
               value = value_accessor ? item.instance_eval(value_accessor) : item
               unless item == selected
                 builder.option item, :value => value
               else  
                 builder.option item, selected => (selected_value.nil? ? 'yes' : selected_value), :value => value
               end
            end
          else
            source = Utils.evaluate_tag_attribute('source', tag)
            if source.respond_to? :each
              source.each do |item|
                value = value_accessor ? item.instance_eval(value_accessor) : item
                unless item == selected
                  builder.option item, :value => value
                else  
                  builder.option item, :selected => (selected_value.nil? ? 'yes' : selected_value), :value => value
                end
              end
            elsif source.respond_to? :each_pair
              source.each_pair do |name,value|
                unless value == selected
                  builder.option name, :value => value
                else  
                  builder.option name, :selected => (selected_value.nil? ? value : selected_value), :value => value
                end
              end
            end
          end    
        end         
      end
    end
    
    
    # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
    # assigned to the template (identified by +object+). The text of label will default to the attribute name unless you specify
    # it explicitly. Additional options on the label tag can be passed as a hash with +options+. These options will be tagged
    # onto the HTML as an HTML element attribute as in the example shown.
    #
    # ==== Examples
    #   label(:post, :title)
    #   #=> <label for="post_title">Title</label>
    #
    #   label(:post, :title, "A short title")
    #   #=> <label for="post_title">A short title</label>
    #
    #   label(:post, :title, "A short title", :class => "title_label")
    #   #=> <label for="post_title" class="title_label">A short title</label>
    class Label < Trellis::Component
      render do |tag|
        target = "#{tag.locals.form_name}_#{tag.attr['for']}"  
        contents = tag.expand
        builder = Builder::XmlMarkup.new
        builder.label(contents, :for => target)        
      end
    end
      
    # Creates a file upload field.  If you are using file uploads then you will also need 
    # to set the multipart option for the form tag:
    #
    #   <%= form_tag { :action => "post" }, { :multipart => true } %>
    #     <label for="file">File to Upload</label> <%= file_field_tag "file" %>
    #     <%= submit_tag %>
    #   <%= end_form_tag %>
    #
    # The specified URL will then be passed a File object containing the selected file, or if the field 
    # was left blank, a StringIO object.
    #
    # ==== Options
    # * Creates standard HTML attributes for the tag.
    # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
    #
    # ==== Examples
    #   file_field_tag 'attachment'
    #   # => <input id="attachment" name="attachment" type="file" />
    #
    #   file_field_tag 'avatar', :class => 'profile-input'
    #   # => <input class="profile-input" id="avatar" name="avatar" type="file" />
    #
    #   file_field_tag 'picture', :disabled => true
    #   # => <input disabled="disabled" id="picture" name="picture" type="file" />
    #
    #   file_field_tag 'resume', :value => '~/resume.doc'
    #   # => <input id="resume" name="resume" type="file" value="~/resume.doc" />
    #
    #   file_field_tag 'user_pic', :accept => 'image/png,image/gif,image/jpeg'
    #   # => <input accept="image/png,image/gif,image/jpeg" id="user_pic" name="user_pic" type="file" /> 
    #
    #   file_field_tag 'file', :accept => 'text/html', :class => 'upload', :value => 'index.html'
    #   # => <input accept="text/html" class="upload" id="file" name="file" type="file" value="index.html" />
    class File < Trellis::Component
      
      render do |tag|
        
      end
    end
      
    # TODO: Need radio button group and a standalone radio button
    

    #
    #
    #
    class Grid < Trellis::Component
      is_stateful
      
      tag_name "grid"
      
      attr_accessor :source
      field :page_position, :persistent => true
      attr_reader :properties
      attr_reader :commands
      attr_reader :counter_method
      attr_reader :counter_method_arguments
      attr_reader :retrieve_block
      attr_reader :sort_properties
      field :sorted_by, :persistent => true
      field :sort_direction, :persistent => true, :default_value => :ascending
      
      def initialize
        @properties = []
        @sort_properties = []
        @commands = []
      end
      
      # must be called before rendering
      def columns(*syms)
        syms.each do |sym|
          @properties << sym
        end
      end
      
      def add_command(options=[])
        # extract options
        name = options[:name] if options
        page = options[:page] if options
        context = options[:context] if options
        image = options[:image] if options

        @commands << lambda do |tag, object| 
          tid = tag.attr['tid']
          value = object.send(context.to_sym)
          url_root = tag.globals.page.class.url_root
          page = tag.globals.page.class.name unless page
          
          href = "#{url_root}/#{page}.#{name}_#{tid}/#{value}"            
        
          %{
          <a href="#{href}">
            <img src='#{image}'/>
          </a>
          }
        end
      end
      
      def sort_by_all_except(*syms)
        @sort_properties = @properties.reject { |property| syms.includes?(property)}
      end
      
      def sort_by(*syms)
        unless syms.first == :all
          @sort_properties = syms
        else
          @sort_properties = @properties
        end
      end
      
      def size_accessor(symbol, args)
        @counter_method, @counter_method_arguments = symbol, args        
      end
      
      def retrieve_method(&block)
        @retrieve_block = block
      end
      
      # event handlers
      
      def on_page(page)
        @page_position = page.to_i # must use the cohersion built in capabilities
      end
      
      def on_sort(property)
        to_sym = property.to_sym
        if @sort_properties.include?(to_sym)
          if @sorted_by != to_sym
            @sorted_by = to_sym
          else  
            @sort_direction = @sort_direction == :ascending ? :descending : :ascending
          end          
        end
      end
      
      render do |tag|
        url_root = tag.globals.page.class.url_root
        # get the page object
        page = tag.globals.page
        # get the tag properties
        tid = tag.attr['tid']
        rows_per_page = tag.attr['rows_per_page'] || 3
        # get the instance of the component from the page
        grid = page.send("grid_#{tid}")
        # get the properties or columns
        properties = grid.properties
        # get the sort properties
        sort_properties = grid.sort_properties
        # current page
        current_page = grid.page_position || 1
        # sort information
        sorted_by = grid.sorted_by
        sort_direction = grid.sort_direction
        commands = grid.commands
        # get the source from either the tag or the component instance itself
        source = tag.attr['source'] || grid.source
        # get the array or collection that we can iterate over
        iterator = tag.locals.send(source.to_sym) || tag.globals.send(source.to_sym)
        
        builder = Builder::XmlMarkup.new
        
        # build the table
        builder.div(:class => "t-data-grid") {
      
          # configure pagination
          #TODO need to implement page ranging
          range = tag.attr['page_range'] || 5
          available_rows = 0
          unless grid.counter_method
            available_rows = iterator.length
          else
            unless grid.counter_method_arguments
              available_rows = iterator.send(grid.counter_method)
            else
              available_rows = iterator.send(grid.counter_method, grid.counter_method_arguments)
            end
          end

          # configure the pager
          pager = Paginator.new(available_rows, rows_per_page) do |offset, per_page|
            rows = nil
            unless grid.retrieve_method
              if sorted_by
                iterator = iterator.sort_by { |row| row.send(sorted_by) }
                iterator.reverse! if sort_direction == :descending
              end
              rows = iterator[offset, per_page]
            else
              rows = grid.retrieve_method.call
            end
            rows
          end

          # get the current page from the pager
          rows = pager.page(current_page)

          # render the pager control if necessary
          unless pager.number_of_pages < 2
            builder.div(:class => "t-data-grid-pager") {
              # loop over the pages
              (1..pager.number_of_pages).each do |page_num|
                if page_num == current_page
                  builder.span("#{page_num}", :class => "current")
                else
                  builder.a("#{page_num}", :href => "#{url_root}/#{page.class.name}.page_grid#{tid}/#{page_num}", :title => "Go to page #{page_num}")                   
                end
              end
            }
          end
                  
          # build the html
          builder.table(:class => "t-data-grid") {
            # header
            builder.thead {
              builder.tr {
                properties.each_index { |index| 
                  property = properties[index]
                  field_name = property.to_s.humanize
  
                  if properties.length == index + 1
                    css_class = "#{field_name} t-last"
                  elsif index == 0
                    css_class = "#{field_name} t-first"
                  else
                    css_class = "#{field_name}"
                  end
                  
                  sort_image = 'sortable.png'
                  if property == sorted_by
                    if sort_direction == :ascending
                      sort_image = 'sort-desc.png'
                    elsif sort_direction == :descending
                      sort_image = 'sort-asc.png'
                    end 
                  end
                  
                  unless sort_properties.include?(property)
                    builder.th(field_name, :class => css_class) 
                  else
                    builder.th(:class => css_class) {
                      builder.a(field_name, :href => "#{url_root}/#{page.class.name}.sort_grid#{tid}/#{property}")
                      builder.a(:href => "#{url_root}/#{page.class.name}.sort_grid#{tid}/#{property}") {
                        builder.img(:alt => "[Sortable]", :class => "t-sort-icon", :id => "#{property}:sort", :src => "#{url_root}/images/#{sort_image}", :name => "#{property}:sort")
                      }
                    }
                  end
                }     
                # add columns for commands
                if commands && !commands.empty?
                  (1..commands.size).each do
                    builder.th 
                  end
                end                 
              }
            }

            # body
            builder.tbody {
              # data
              index = 0
              rows.each do |item|
                if (rows.last_item_number - rows.first_item_number) == index + 1
                  css_class = "t-last"
                elsif index == 0
                  css_class = "t-first"
                else
                  css_class = nil
                end
                index = index + 1
                
                if css_class
                  builder.tr(:class => css_class) {
                    properties.each { |property|
                      field_value = item.send(property)
                      builder.td("#{field_value}", :class => "#{property}")
                    }
                    # add columns for commands
                    if commands && !commands.empty?                     
                      commands.each { |command|
                        builder.td { |td| td << command.call(tag, item)}
                      }
                    end 
                  }
                else
                  builder.tr {
                    properties.each { |property|
                      field_value = item.send(property)
                      builder.td("#{field_value}", :class => "#{property}")
                    }
                    # add columns for commands
                    if commands && !commands.empty?                     
                      commands.each { |command|
                        builder.td { |td| td << command.call(tag, item)}
                      }
                    end 
                  }                  
                end
              end if rows       
            }
          }
        }
      end  
    end
    
    class ObjectEditor < Trellis::Component
      is_stateful
      
      depends_on :form, :submit
      
      field :model, :persistent => true
      attr_reader :retrieve_block
      attr_reader :properties
      attr_accessor :submit_text
      attr_reader :submit_block
      
      def initialize
        @properties = []
      end
      
      # must be called before rendering
      def fields(*syms)
        syms.each do |sym|
          @properties << sym
        end
      end
      
      def on_submit(&block) 
        # populate the object with values from the session
        if page.params
          properties.each do |property|
            value = page.params[property.to_sym]
            @model.instance_variable_set("@#{property}".to_sym, value)
          end
        end
        if block_given?
          @submit_block = block
        else
          @submit_block.call(@model)
        end
      end
      
      render do |tag|
        url_root = tag.globals.page.class.url_root
        # get the page object
        page = tag.globals.page
        # get the tag properties
        tid = tag.attr['tid']
        # get the instance of the component from the page
        editor = page.send("object_editor_#{tid}")
        # get the properties or columns
        properties = editor.properties
        # get the source from either the tag or the component instance itself
        source = tag.attr['model'] || editor.model
        submit_text = tag.attr['submit_text'] || editor.submit_text || "Submit"

        builder = Builder::XmlMarkup.new
        
        # the editor encloses a form
        form = tag.render("form", "tid" => "form_#{tid}", "method" => "post", "on_behalf" => "object_editor#{tid}") do
          builder.div(:class => "t-beaneditor") {
            properties.each { |property|
              field_name = property.to_s.humanize
              field_value = source.send(property)
              builder.div(:class => "t-beaneditor-row") {
                builder.label(field_name, :for => property, :id => "#{property}:label")
                builder.input(:id => property, :name => property, :type => "text", :value => field_value)
                builder.img(:alt => "[Error]", :class => "t-error-icon t-invisible", :id => "#{property}:icon", :src => "#{url_root}/images/field-error-marker.gif", :name => "#{property}:icon")     
              }
            } if source
            builder.div(:class => "t-beaneditor-row") {
              builder << tag.render("submit", "tid" => "submit", "name" => "whats_the_name", "value" => submit_text)
            }
          }
        end
        form
      end

    end
    
    class Div < Trellis::Component
      render do |tag|
        attrs = tag.attr.exclude_keys('id', 'title')
        attrs['id'] = Utils.expand_properties_in_tag(tag.attr['id'], tag) if tag.attr['id']
        attrs['title'] = Utils.expand_properties_in_tag(tag.attr['title'], tag) if tag.attr['title']
        builder = Builder::XmlMarkup.new
        builder.div(attrs) { |div|
          div << tag.expand
        }
      end
    end
    
  end
end